# Pretty prompt does not work except in Windows Terminal
if ([bool]($env:WT_Session)) {
    Set-Theme Paradox
}
else {
    function prompt {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideCommentHelp', '', Scope = 'Function')]
        param()
        $History = Get-History
        if ($History.Count -gt 0) {
            $PreviousCommand = $History[$History.Count - 1]
        }

        $CommandPrompt = if ($PreviousCommand) { "Previous Command: $PreviousCommand" } else { "Previous Command: None" }

        "$CommandPrompt [$(Get-Date)] `n PS $($executionContext.SessionState.Path.CurrentLocation)$('> ' * ($nestedPromptLevel + 1))";
    }
}

