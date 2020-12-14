// --------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license.
// --------------------------------------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using Microsoft.Oryx.BuildScriptGenerator.Common;
using Microsoft.Oryx.BuildScriptGeneratorCli;
using Microsoft.Oryx.Tests.Common;
using Xunit;
using Xunit.Abstractions;

namespace Microsoft.Oryx.BuildImage.Tests
{
    [Trait("platform", "ruby")]
    public class RubyDynamicInstallationTest : SampleAppsTestBase
    {
        public RubyDynamicInstallationTest(ITestOutputHelper output) : base(output)
        {
        }

        private DockerVolume CreateSampleAppVolume(string sampleAppName) =>
            DockerVolume.CreateMirror(Path.Combine(_hostSamplesDir, "ruby", sampleAppName));

        public static TheoryData<string> ImageNameData
        {
            get
            {
                var data = new TheoryData<string>();
                var imageTestHelper = new ImageTestHelper();
                data.Add(imageTestHelper.GetVsoBuildImage());
                data.Add(imageTestHelper.GetVsoBuildImage("vso-focal"));
                data.Add(imageTestHelper.GetGitHubActionsBuildImage());
                return data;
            }
        }

        [SkippableTheory] //Temporarily skipping, workitem#1257778
        [MemberData(nameof(ImageNameData))]
        public void GeneratesScript_AndBuildSinatraAppWithDynamicInstall(string buildImageName)
        {
            // Arrange
            var appName = "sinatra-app";
            var volume = CreateSampleAppVolume(appName);
            var appDir = volume.ContainerDir;
            var appOutputDir = "/tmp/app-output";
            var script = new ShellScriptBuilder()
                .AddDefaultTestEnvironmentVariables()
                .AddBuildCommand($"{appDir} -o {appOutputDir}")
                .ToString();

            // Act
            var result = _dockerCli.Run(new DockerRunArguments
            {
                ImageId = buildImageName,
                EnvironmentVariables = new List<EnvironmentVariable> { CreateAppNameEnvVar(appName) },
                Volumes = new List<DockerVolume> { volume },
                CommandToExecuteOnRun = "/bin/bash",
                CommandArguments = new[] { "-c", script }
            });

            // Assert
            RunAsserts(
                () =>
                {
                    Assert.True(result.IsSuccess);
                    Assert.Contains("Ruby version", result.StdOut);
                },
                result.GetDebugInfo());
        }
    }
}