// Godot on macOS ignores XDG_DATA_HOME and keeps user:// under $HOME/Library/Application Support
// (platform/macos/os_macos.mm), so a scratch data home isolates a run there only when HOME moves
// with it. Linux and Windows keep the caller's HOME.
export function userDataEnv(dir, platform = process.platform) {
  return platform === "darwin" ? { XDG_DATA_HOME: dir, HOME: dir } : { XDG_DATA_HOME: dir };
}

// An import or a boot run takes no scratch data home, but on macOS it still writes editor
// settings and logs under HOME, so there it gets a scratch HOME of its own.
export function scratchHomeEnv(makeDir, platform = process.platform) {
  return platform === "darwin" ? { HOME: makeDir() } : {};
}
