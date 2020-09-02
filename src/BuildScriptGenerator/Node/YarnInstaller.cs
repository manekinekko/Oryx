// --------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license.
// --------------------------------------------------------------------------------------------

using System.IO;
using System.Text;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.Oryx.BuildScriptGenerator.Common;

namespace Microsoft.Oryx.BuildScriptGenerator.Node
{
    public class YarnInstaller : PlatformInstallerBase
    {
        public YarnInstaller(
            IOptions<BuildScriptGeneratorOptions> commonOptions,
            ILoggerFactory loggerFactory)
            : base(commonOptions, loggerFactory)
        {
        }

        public virtual string GetInstallerScriptSnippet(string version)
        {
            var tarFile = YarnConstants.DownloadTarFileNameFormat.Replace("#VERSION#", version);
            var downloadUrl = YarnConstants.DownloadUrlFormat.Replace("#VERSION#", version);
            var platformName = "yarn";
            var versionDirInTemp = Path.Combine(CommonOptions.DynamicInstallRootDir, platformName, version);

            var snippet = new StringBuilder();
            snippet
                .AppendLine()
                .AppendLine("PLATFORM_SETUP_START=$SECONDS")
                .AppendLine("echo")
                .AppendLine(
                $"echo Downloading and extracting {platformName} version '{version}' to {versionDirInTemp}...")
                .AppendLine($"rm -rf {versionDirInTemp}")
                .AppendLine($"mkdir -p {versionDirInTemp}")
                .AppendLine($"cd {versionDirInTemp}")
                .AppendLine("PLATFORM_BINARY_DOWNLOAD_START=$SECONDS")
                .AppendLine($"curl -fsSLO --compressed \"{downloadUrl}\" >/dev/null 2>&1")
                .AppendLine("PLATFORM_BINARY_DOWNLOAD_ELAPSED_TIME=$(($SECONDS - $PLATFORM_BINARY_DOWNLOAD_START))")
                .AppendLine("echo \"Downloaded in $PLATFORM_BINARY_DOWNLOAD_ELAPSED_TIME sec(s).\"")
                .AppendLine("echo Extracting contents...")
                .AppendLine($"tar -xzf {tarFile} -C .")
                .AppendLine($"rm -f {tarFile}")
                .AppendLine("PLATFORM_SETUP_ELAPSED_TIME=$(($SECONDS - $PLATFORM_SETUP_START))")
                .AppendLine("echo \"Done in $PLATFORM_SETUP_ELAPSED_TIME sec(s).\"")
                .AppendLine("echo")

                // Write out a sentinel file to indicate downlaod and extraction was successful
                .AppendLine($"echo > {Path.Combine(versionDirInTemp, SdkStorageConstants.SdkDownloadSentinelFileName)}");
            return snippet.ToString();
        }

        public virtual bool IsVersionAlreadyInstalled(string version)
        {
            return IsVersionInstalled(
                version,
                builtInDir: YarnConstants.InstalledYarnVersionsDir,
                dynamicInstallDir: Path.Combine(CommonOptions.DynamicInstallRootDir, YarnConstants.PlatformName));
        }
    }
}
