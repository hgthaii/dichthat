# DichThat feature flows

This Mermaid Diagram Document describes the implemented product flows in the current source. Each diagram stays focused enough to review independently while sharing the same feature boundaries.

## 1. Launch and first-run setup

```mermaid
flowchart TD
    launch([Launch DichThat]) --> instance{Another instance running?}
    instance -->|Yes| activate[Activate existing app]
    activate --> stopDuplicate([Exit duplicate process])
    instance -->|No| disk{Running from read-only volume?}
    disk -->|Yes| installPrompt[Prompt user to move app]
    installPrompt --> openApps[Open Applications folder]
    openApps --> stopLaunch([Exit app])
    disk -->|No| startApp[Start menu-bar app]
    startApp --> startUpdater[Start Sparkle updater]
    startApp --> loadPrefs[Load shortcut and preferences]
    startApp --> checkAccess{Accessibility granted?}
    checkAccess -->|No| pollAccess[Show permission state and poll]
    checkAccess -->|Yes| observeSelection[Start selection observation]
    startApp --> checkLanguages{English and Vietnamese ready?}
    checkLanguages -->|No| openSetup[Open Settings setup]
    openSetup --> prepareLanguages[Ask Apple Translation to prepare both pairs]
    prepareLanguages --> prepared{Preparation succeeded?}
    prepared -->|No| setupError[Show download error]
    prepared -->|Yes| enableFeatures[Enable translation features]
    checkLanguages -->|Yes| enableFeatures
```

## 2. Quick Translate from selected text

```mermaid
flowchart TD
    selectText[/Select text in another app/]
    selectText --> trigger[/Press global shortcut or click selection icon/]
    trigger --> languageReady{Translation languages ready?}
    languageReady -->|No| ignoreTrigger[Keep translation unavailable]
    languageReady -->|Yes| resolveTarget[Resolve frontmost external process]
    resolveTarget --> rememberAnchor[Read observed selection anchor]
    rememberAnchor --> access{Accessibility granted?}
    access -->|No| permissionError[Show permission error near pointer]
    access -->|Yes| captureGate{Capture already active?}
    captureGate -->|Yes| busyError[Show capture-in-progress error]
    captureGate -->|No| axCapture[Try Accessibility selected-text capture]
    axCapture --> axResult{Text captured?}
    axResult -->|Yes| resolveAnchor[Prefer confirmed or observed selection anchor]
    axResult -->|No| clipboardCapture[Snapshot clipboard and send Command-C]
    clipboardCapture --> restoreClipboard[Restore snapshot with race guards]
    restoreClipboard --> clipboardResult{Text captured and restored?}
    clipboardResult -->|No| captureError[Show capture error]
    clipboardResult -->|Yes| resolveAnchor
    resolveAnchor --> reuse{Matching translation cached?}
    reuse -->|Yes| showResult[Show translation beside selection]
    reuse -->|No| translate[Run translation engine]
    translate --> requestCurrent{Request still current?}
    requestCurrent -->|No| discard[Discard stale completion]
    requestCurrent -->|Yes| showResult
    showResult --> outside[/Click outside or selection changes/]
    outside --> dismiss[Cancel work, stop speech, hide panel]
```

## 3. Language routing and translation enrichment

```mermaid
flowchart TD
    input[/Input text/]
    input --> normalize[Trim and validate length]
    normalize --> valid{Input valid?}
    valid -->|No| inputError[Return empty, long, or ambiguous error]
    valid -->|Yes| detect[Score English and Vietnamese with NaturalLanguage]
    detect --> supported{Confident EN or VI?}
    supported -->|No| languageError[Return unsupported or ambiguous error]
    supported -->|Yes| route[Set source and opposite target language]
    route --> mode{Single English dictionary word?}
    route --> appleTranslate[Translate with Apple Translation]
    mode -->|No| compact[Use compact result]
    mode -->|Yes| dictionary[(Read bundled SQLite dictionary)]
    dictionary --> entry{Dictionary entry found?}
    entry -->|No| compact
    entry -->|Yes| enrich[Load pronunciation, meanings, examples, synonyms]
    enrich --> localize[Translate definition and example snippets to Vietnamese]
    appleTranslate --> translated{Translation succeeded?}
    translated -->|No| translationError[Return translation failure]
    translated -->|Yes| merge{Enrichment available?}
    compact --> merge
    localize --> merge
    merge --> output[/Return translation output/]
```

## 4. Direct input from the menu bar

```mermaid
flowchart TD
    clickIcon[/Left-click menu-bar icon/]
    clickIcon --> visible{Translation panel visible?}
    visible -->|Yes| closePanel[Dismiss panel]
    visible -->|No| ready{Translation languages ready?}
    ready -->|No| noInput[Do not open input]
    ready -->|Yes| showInput[Show input anchored to menu bar]
    showInput --> type[/User types text/]
    type --> normalize[Trim input and cancel previous request]
    normalize --> empty{Input empty?}
    empty -->|Yes| prompt[Show input prompt]
    empty -->|No| cached{Cached result available?}
    cached -->|Yes| result[Show cached translation]
    cached -->|No| debounce[Wait for input debounce]
    debounce --> latest{Still latest request?}
    latest -->|No| discard[Discard cancelled request]
    latest -->|Yes| loading[Show loading state]
    loading --> engine[Run language routing and translation]
    engine --> result
```

Right-clicking the menu-bar icon opens the command menu for permission setup, update checks, Settings, and Quit. Before language preparation completes, the menu exposes only Settings and Quit.

## 5. Selection observation and optional icon

```mermaid
flowchart TD
    preference{Selection icon feature enabled?}
    preference -->|No| anchorOnly[Monitor gestures without presenting icon]
    preference -->|Yes| permission{Accessibility granted?}
    permission -->|No| permissionState[Report permission required]
    permission -->|Yes| monitor[Install global mouse monitor]
    anchorOnly --> monitor
    monitor --> gesture[/Mouse selection gesture/]
    gesture --> remember[Store mouse-up point and target process]
    remember --> inspect[Inspect selection through Accessibility]
    inspect --> valid{Selection appears valid?}
    valid -->|No| keepAnchor[Keep gesture anchor for shortcut]
    valid -->|Yes| iconAllowed{Presenting icon allowed?}
    iconAllowed -->|No| keepAnchor
    iconAllowed -->|Yes| showIcon[Show temporary icon by selection]
    showIcon --> action{User action}
    action -->|Click icon| quickTranslate[Start Quick Translate capture]
    action -->|Scroll, new click, timeout| invalidate[Hide icon and invalidate selection]
```

The selection-icon UI is currently disabled by `AppConfiguration.Features.selectionIconEnabled`. Gesture observation remains useful because it preserves the selection endpoint for accurate popup placement.

## 6. Translation result actions

```mermaid
flowchart TD
    result[/Translation result shown/]
    result --> content[Display source, translation, and optional dictionary details]
    content --> speechAvailable{Matching macOS voice available?}
    speechAvailable -->|No| unavailable[Keep speech unavailable]
    speechAvailable -->|Yes| speak[/User requests pronunciation/]
    speak --> replace{Speech already active?}
    replace -->|Yes| stopOld[Stop current utterance]
    replace -->|No| play[Speak source content]
    stopOld --> play
    result --> dismissAction[/Click outside, close, or change selection/]
    dismissAction --> stopSpeech[Stop speech]
    stopSpeech --> hideResult[Hide translation panel]
```

## 7. Settings and system integrations

```mermaid
flowchart TD
    openSettings[/Open Settings/]
    openSettings --> refresh[Refresh permission, language, and update state]
    refresh --> setup{Setup action required?}
    setup -->|Accessibility| requestAccess[Open macOS permission prompt]
    setup -->|Translation languages| prepare[Prepare EN and VI language pairs]
    setup -->|None| general[Show General settings]
    general --> shortcut[/Change global shortcut/]
    shortcut --> register{Shortcut registration succeeds?}
    register -->|No| shortcutError[Keep previous shortcut and show error]
    register -->|Yes| saveShortcut[Persist new shortcut]
    general --> login[/Toggle launch at login/]
    login --> service[Update macOS login item]
    general --> bug[/Report a bug/]
    bug --> diagnostics[Collect app and system metadata only]
    diagnostics --> issue[Open prefilled GitHub issue]
    openSettings --> about[Show version and data sources]
```

## 8. Update flow

```mermaid
flowchart TD
    updateTrigger[/Choose Check for Updates/]
    updateTrigger --> checkGate{Check already active?}
    checkGate -->|Yes| keepState[Keep current update state]
    checkGate -->|No| canCheck{Sparkle can start a check?}
    canCheck -->|No| checkError[Show unavailable error]
    canCheck -->|Yes| fetch[Fetch and validate appcast]
    fetch --> available{New version available?}
    available -->|No| upToDate[Show up-to-date state]
    available -->|Yes| offer[Show available version]
    offer --> install[/User chooses Install/]
    install --> sparkle[Let Sparkle download and install update]
```

## 9. Data and privacy boundary

```mermaid
flowchart LR
    selected[/Selected or typed text/] --> memory[Ephemeral in-memory request]
    memory --> apple[Apple Translation on device]
    memory --> dictionary[(Bundled offline dictionary)]
    clipboard[/Clipboard fallback/] --> snapshot[Temporary guarded snapshot]
    snapshot --> memory
    snapshot --> restore[Restore original clipboard]
    apple --> panel[/Translation panel/]
    dictionary --> panel
    panel --> dismiss[Dismiss or invalidate]
    dismiss --> release[Release request state and stop speech]
    diagnostics[/Bug report/] --> metadata[System and app metadata only]
```

DichThat does not persist translation history, selected text, or clipboard contents, and it does not include that content in diagnostics. The clipboard path is a fallback used only when Accessibility capture cannot return selected text.
