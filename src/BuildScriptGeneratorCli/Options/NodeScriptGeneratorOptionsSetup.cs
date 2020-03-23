﻿// --------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license.
// --------------------------------------------------------------------------------------------

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using Microsoft.Oryx.BuildScriptGenerator.Node;

namespace Microsoft.Oryx.BuildScriptGeneratorCli.Options
{
    public class NodeScriptGeneratorOptionsSetup : OptionsSetupBase, IConfigureOptions<NodeScriptGeneratorOptions>
    {
        public NodeScriptGeneratorOptionsSetup(IConfiguration configuration)
            : base(configuration)
        {
        }

        public void Configure(NodeScriptGeneratorOptions options)
        {
            options.NodeVersion = GetStringValue(SettingsKeys.NodeVersion);
            options.CustomNpmRunBuildCommand = GetStringValue(SettingsKeys.CustomNpmRunBuildCommand);
        }
    }
}