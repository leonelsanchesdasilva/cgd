module updater;

import std.stdio;
import std.json;
import std.net.curl;
import std.string;
import std.conv;
import std.file;
import std.path;
import std.process;
import std.algorithm;
import std.array;
import std.zip;
import std.exception;
import std.datetime;
import std.typecons;

enum UpdateResult
{
    Success,
    AlreadyUpToDate,
    DownloadFailed,
    CompilationFailed,
    InstallationFailed,
    UserCancelled,
    NetworkError,
    InvalidResponse
}

/// Encapsulates release information from GitHub API
struct ReleaseInfo
{
    string tagName;
    string downloadUrl;
    string name;
    string description;
    SysTime publishedAt;
    bool isNewer;
    ulong downloadSize;
}

/// Configuration structure for updater behavior
struct UpdaterConfig
{
    bool verbose = false;
    bool autoConfirm = false;
    bool createBackup = true;
    string tempDirectory = null;
    Duration timeout = dur!"seconds"(30);
}

class Updater
{
    private
    {
        immutable string repoOwner;
        immutable string repoName;
        immutable string currentVersion;
        UpdaterConfig config;

        enum string USER_AGENT = "Professional-Updater/1.0";
        enum string API_BASE_URL = "https://api.github.com/repos";
    }

    this(string owner, string repo, string _version, UpdaterConfig config = UpdaterConfig())
    {
        this.repoOwner = owner;
        this.repoName = repo;
        this.currentVersion = _version;
        this.config = config;

        if (this.config.tempDirectory is null || this.config.tempDirectory.empty)
            this.config.tempDirectory = buildPath(tempDir(), "updater-workspace");
    }

    Nullable!ReleaseInfo checkForUpdates()
    {
        logVerbose("Verificando atualizações do repositório: %s/%s", repoOwner, repoName);

        try
        {
            auto resposta = makeApiRequest();
            if (resposta.isNull)
                return Nullable!ReleaseInfo.init;

            return parseReleaseResponse(resposta.get);
        }
        catch (Exception e)
        {
            logError("Verificação de atualização falhou: %s", e.msg);
            logVerbose("Erro: %s", e.toString());
            return Nullable!ReleaseInfo.init;
        }
    }

    UpdateResult performUpdate()
    {
        writeln("Iniciando verificação de atualizações...");

        auto infoRelease = checkForUpdates();
        if (infoRelease.isNull)
            return UpdateResult.NetworkError;

        auto info = infoRelease.get;

        if (!info.isNewer)
        {
            writeln("Sistema está executando a versão mais recente: " ~ currentVersion);
            return UpdateResult.AlreadyUpToDate;
        }

        displayUpdateInfo(info);

        if (!config.autoConfirm && !getUserConfirmation())
            return UpdateResult.UserCancelled;

        return executeUpdate(info);
    }

private:

    Nullable!string makeApiRequest()
    {
        string urlApi = format("%s/%s/%s/releases/latest", API_BASE_URL, repoOwner, repoName);
        logVerbose("Endpoint da API: %s", urlApi);

        try
        {
            HTTP http = HTTP();
            configureHttpClient(http);

            char[] dadosResposta;
            http.onReceive = (ubyte[] data) {
                dadosResposta ~= cast(char[]) data;
                return data.length;
            };

            http.url(urlApi);
            http.perform();

            auto codigoStatus = http.statusLine.code;
            if (codigoStatus != 200)
            {
                logError("API do GitHub retornou status %d", codigoStatus);
                return Nullable!string.init;
            }

            return nullable(cast(string) dadosResposta);
        }
        catch (CurlException e)
        {
            logError("Requisição de rede falhou: %s", e.msg);
            return Nullable!string.init;
        }
    }

    void configureHttpClient(ref HTTP http)
    {
        http.addRequestHeader("User-Agent", USER_AGENT);
        http.addRequestHeader("Accept", "application/vnd.github+json");
        http.connectTimeout = config.timeout;
        http.dataTimeout = config.timeout;
    }

    Nullable!ReleaseInfo parseReleaseResponse(string responseData)
    {
        try
        {
            JSONValue json = parseJSON(responseData);
            ReleaseInfo info;

            info.tagName = json["tag_name"].str;
            info.name = json["name"].str;
            if ("body" in json)
                info.description = json["body"].str;
            else
                info.description = "";
            info.downloadUrl = extractDownloadUrl(json);
            info.isNewer = isNewerVersion(info.tagName, currentVersion);

            if ("published_at" in json)
            {
                // Parse ISO 8601 timestamp
                auto timeStr = json["published_at"].str;
                info.publishedAt = SysTime.fromISOExtString(timeStr);
            }

            logVerbose("Versão atual: %s", currentVersion);
            logVerbose("Ultima versão: %s", info.tagName);
            logVerbose("Atualização disponível: %s", info.isNewer ? "Sim" : "Não");

            return nullable(info);
        }
        catch (JSONException e)
        {
            logError("Falha ao parsear a resposta da API: %s", e.msg);
            return Nullable!ReleaseInfo.init;
        }
    }

    string extractDownloadUrl(JSONValue json)
    {
        if ("assets" in json && json["assets"].array.length > 0)
        {
            foreach (asset; json["assets"].array)
            {
                string assetName = asset["name"].str;
                if (isSuitableAsset(assetName))
                {
                    if ("size" in asset)
                        logVerbose("Asset size: %d bytes", asset["size"].integer);
                    return asset["browser_download_url"].str;
                }
            }
        }

        return json["tarball_url"].str;
    }

    bool isSuitableAsset(string assetName)
    {
        version (Windows)
        {
            return assetName.endsWith(".exe") || assetName.endsWith("-windows.exe");
        }
        else version (linux)
        {
            return assetName.endsWith("-linux") || (assetName == "cgd" && !assetName.canFind("."));
        }
        else
        {
            return assetName == "cgd" || assetName == "cgd.exe";
        }
    }

    bool isNewerVersion(string latestTag, string currentVer)
    {
        string latest = normalizeVersion(latestTag);
        string current = normalizeVersion(currentVer);

        auto latestParts = parseVersionParts(latest);
        auto currentParts = parseVersionParts(current);

        return compareVersionParts(latestParts, currentParts) > 0;
    }

    string normalizeVersion(string version_)
    {
        return version_.startsWith("v") ? version_[1 .. $] : version_;
    }

    int[] parseVersionParts(string version_)
    {
        try
        {
            return version_.split(".").map!(to!int).array;
        }
        catch (ConvException)
        {
            logVerbose("Aviso: formato de versão inválido: %s", version_);
            return [0];
        }
    }

    int compareVersionParts(int[] latest, int[] current)
    {
        size_t maxLength = max(latest.length, current.length);

        while (latest.length < maxLength)
            latest ~= 0;
        while (current.length < maxLength)
            current ~= 0;

        for (size_t i = 0; i < maxLength; i++)
        {
            if (latest[i] > current[i])
                return 1;
            if (latest[i] < current[i])
                return -1;
        }

        return 0;
    }

    void displayUpdateInfo(ReleaseInfo info)
    {
        writeln();
        writeln("Atualização disponível");
        writeln("================");
        writefln("Versão atual:    %s", currentVersion);
        writefln("Ultima versão:   %s", info.tagName);
        writefln("Nome da versão:  %s", info.name);

        if (!info.description.empty && info.description.length < 200)
        {
            writeln("Descrição:");
            writeln(info.description);
        }
        writeln();
    }

    bool getUserConfirmation()
    {
        write("Prosseguir com a instalação da atualização? [s/N]: ");
        stdout.flush();

        string response = readln().strip().toLower();
        return response.among("y", "yes", "s", "sim") > 0;
    }

    UpdateResult executeUpdate(ReleaseInfo info)
    {
        writeln("Iniciando processo de atualização...");

        try
        {
            ensureWorkspaceDirectory();

            string downloadPath = buildPath(config.tempDirectory, "source.tar.gz");

            if (!downloadSource(info.downloadUrl, downloadPath))
                return UpdateResult.DownloadFailed;

            if (!compileFromSource(downloadPath))
                return UpdateResult.CompilationFailed;

            if (!installNewVersion())
                return UpdateResult.InstallationFailed;

            writeln("Atualização concluída com sucesso.");

            return UpdateResult.Success;
        }
        catch (Exception e)
        {
            logError("O processo de atualização falhou: %s", e.msg);
            return UpdateResult.InstallationFailed;
        }
    }

    void ensureWorkspaceDirectory()
    {
        if (!exists(config.tempDirectory))
        {
            logVerbose("Criando diretório de espaço de trabalho: %s", config.tempDirectory);
            mkdirRecurse(config.tempDirectory);
        }
    }

    bool downloadSource(string url, string downloadPath)
    {
        logVerbose("Baixando fonte de: %s", url);

        try
        {
            HTTP http = HTTP();
            configureHttpClient(http);
            download(url, downloadPath, http);

            if (!exists(downloadPath) || getSize(downloadPath) == 0)
            {
                logError("Falha ao verificar instalação");
                return false;
            }

            logVerbose("Instalação completa: %d bytes", getSize(downloadPath));
            return true;
        }
        catch (Exception e)
        {
            logError("Falha no download: %s", e.msg);
            return false;
        }
    }

    bool compileFromSource(string downloadPath)
    {
        string extractDir = buildPath(config.tempDirectory, "source");

        logVerbose("Extraindo fonte para: %s", extractDir);
        if (!extractSource(downloadPath, extractDir))
            return false;

        logVerbose("Compilando...");
        return buildApplication(extractDir);
    }

    bool extractSource(string downloadPath, string extractDir)
    {
        try
        {
            if (exists(extractDir))
                rmdirRecurse(extractDir);
            mkdirRecurse(extractDir);

            auto result = execute([
                "tar", "-xzf", downloadPath, "-C", extractDir,
                "--strip-components=1"
            ]);

            if (result.status != 0)
            {
                logError("Falha na extração da fonte");
                logVerbose("Saída da extração: %s", result.output);
                return false;
            }

            return true;
        }
        catch (Exception e)
        {
            logError("Erro ao extrair: %s", e.msg);
            return false;
        }
    }

    bool buildApplication(string sourceDir)
    {
        try
        {
            auto result = execute([
                "dub", "build", "--build=release", "--compiler=dmd"
            ], null, Config.none, size_t.max, sourceDir);

            if (result.status != 0)
            {
                logError("Falha na compilação");
                logVerbose("Saída da compilação: %s", result.output);
                return false;
            }

            string expectedExecutable = buildPath(sourceDir, "cgd");
            if (!exists(expectedExecutable))
            {
                logError("Executável compilado não encontrado no local esperado");
                return false;
            }

            logVerbose("Sucesso ao compilar: %s", expectedExecutable);
            return true;
        }
        catch (Exception e)
        {
            logError("Erro no processo de construção: %s", e.msg);
            return false;
        }
    }

    bool installNewVersion()
    {
        try
        {
            string newExecutable = buildPath(config.tempDirectory, "source", "cgd");
            string currentExecutable = thisExePath();

            return replaceExecutable(newExecutable, currentExecutable);
        }
        catch (Exception e)
        {
            logError("Falha na instalação: %s", e.msg);
            return false;
        }
    }

    bool replaceExecutable(string newPath, string currentPath)
    {
        string backupPath = currentPath ~ ".backup";
        string tempPath = currentPath ~ ".new";

        logVerbose("Instalando novo executável...");
        logVerbose("Origem: %s", newPath);
        logVerbose("Destino: %s", currentPath);

        try
        {
            copy(newPath, tempPath);

            version (Posix)
            {
                auto chmodResult = execute(["chmod", "+x", tempPath]);
                if (chmodResult.status != 0)
                    logVerbose("Aviso: Falha ao definir permissões executáveis");
            }

            if (config.createBackup && exists(currentPath))
            {
                if (exists(backupPath))
                    remove(backupPath);
                rename(currentPath, backupPath);
                logVerbose("Backup criado: %s", backupPath);
            }

            rename(tempPath, currentPath);

            writeln("Instalação completa com sucesso.");
            if (config.createBackup)
                writefln("Versão anterior com backup em: %s", backupPath);

            return true;
        }
        catch (Exception e)
        {
            logError("Falha na substituição do executável: %s", e.msg);

            try
            {
                if (exists(tempPath))
                    remove(tempPath);
                if (config.createBackup && exists(backupPath) && !exists(currentPath))
                    rename(backupPath, currentPath);
            }
            catch (Exception rollbackError)
            {
                logError("Falha na reversão: %s", rollbackError.msg);
            }

            return false;
        }
    }

    void logVerbose(T...)(string fmt, T args)
    {
        if (config.verbose)
            writefln("[VERBOSE] " ~ fmt, args);
    }

    void logError(T...)(string fmt, T args)
    {
        writefln("[ERROR] " ~ fmt, args);
    }
}
