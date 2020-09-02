// --------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license.
// --------------------------------------------------------------------------------------------

namespace Microsoft.Oryx.BuildScriptGenerator.Node
{
    internal static class YarnConstants
    {
        internal const string DefaultYarnVersion = NodeVersions.YarnVersion;
        internal const string PlatformName = "yarn";
        internal const string InstalledYarnVersionsDir = "/opt/yarn/";
        internal const string DownloadUrlFormat =
            "https://github.com/yarnpkg/yarn/releases/download/v#VERSION#/yarn-v#VERSION#.tar.gz";
        public const string DownloadTarFileNameFormat = "yarn-v#VERSION#.tar.gz";
    }
}
