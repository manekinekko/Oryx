package main

import "flag"
import "os"

import "strings"
import "strconv"
import "startupscriptgenerator/common"

func main() {
	appPathPtr := flag.String("appPath", ".", "The path to the application folder, e.g. '/home/site/wwwroot/'.")
	defaultAppFilePathPtr := flag.String("defaultApp", "", "[Optional] Path to a default file that will be executed if the entrypoint is not found. Ex: '/opt/startup/default-static-site.js'")
	customStartCommandPtr := flag.String("serverCmd", "", "[Optional] Command to start the server, if different than 'node', e.g. 'pm2 start --no-daemon'")
	remoteDebugEnabledPtr := flag.Bool("remoteDebug", false, "Application will run in debug mode.")
	remoteDebugBrkEnabledPtr := flag.Bool("remoteDebugBrk", false, "Application will run in debug mode, and will debugger will break before the user code starts.")
	remoteDebugIp := flag.String("debugHost", "", "The IP address where the debugger will listen to, e.g. '0.0.0.0' or '127.0.0.1")
	remoteDebugPort := flag.String("debugPort", "", "The port the debugger will listen to.")
	flag.Parse()

	fullAppPath := fsvalidation.GetValidatedFullPath(*appPathPtr)
	defaultAppFullPAth := fsvalidation.GetValidatedFullPath(*defaultAppFilePathPtr)
	useLegacyDebugger := isLegacyDebuggerNeeded()

	gen := NodeStartupScriptGenerator{
		SourcePath:                      fullAppPath,
		DefaultAppJsFilePath:            defaultAppFullPAth,
		CustomStartCommand:              *customStartCommandPtr,
		RemoteDebugging:                 *remoteDebugEnabledPtr,
		RemoteDebuggingBreakBeforeStart: *remoteDebugBrkEnabledPtr,
		RemoteDebuggingIp:               *remoteDebugIp,
		RemoteDebuggingPort:             *remoteDebugPort,
		UseLegacyDebugger:               useLegacyDebugger,
	}
	script := gen.GenerateEntrypointCommand()
	println(script)
}

// Checks if the legacy debugger should be used for the current node image
func isLegacyDebuggerNeeded() bool {
	nodeVersionEnv := os.Getenv("NODE_VERSION")
	result := checkLegacyDebugger(nodeVersionEnv)
	return result
}

// Checks if the legacy debugger should be used for a particular node version
func checkLegacyDebugger(nodeVersion string) bool {
	if nodeVersion != "" {
		if splitVersion := strings.Split(nodeVersion, "."); len(splitVersion) >= 2 {
			if majorVersion, majorErr := strconv.ParseInt(splitVersion[0], 0, 0); majorErr == nil {
				if minorVersion, minorErr := strconv.ParseInt(splitVersion[1], 0, 0); minorErr == nil {
					if majorVersion < 7 || (majorVersion == 7 && minorVersion < 7) {
						return true
					}
				}
			}
		}
	}
	return false
}