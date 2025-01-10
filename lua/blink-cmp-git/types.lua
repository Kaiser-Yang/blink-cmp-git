--- @class (exact) blink-cmp-git.DocumentationCommand
--- @field get_command string|fun(): string
--- @field get_command_args string[]|fun(): string[]
--- @field resolve_documentation fun(output: string): string

--- @class (exact) blink-cmp-git.CompletionItem
--- @field label string
--- @field insert_text string
--- @field documentation string|blink-cmp-git.DocumentationCommand

--- @class (exact) blink-cmp-git.GCSCompletionOptions
--- @field enable? boolean|fun(): boolean
--- @field triggers? string[]|fun(): string[]
--- @field get_command? string|fun(): string
--- @field get_command_args? string[]|fun(): string[]
--- @field seperate_output? fun(output: string): blink-cmp-git.CompletionItem[]

--- @class (exact) blink-cmp-git.GCSOptions
--- @field commit? blink-cmp-git.GCSCompletionOptions
--- @field issue? blink-cmp-git.GCSCompletionOptions
--- @field pull_request? blink-cmp-git.GCSCompletionOptions
--- @field mention? blink-cmp-git.GCSCompletionOptions

--- @class (exact) blink-cmp-git.Options
--- @field async? boolean|fun(): boolean
--- @field use_items_cache? boolean|fun(): boolean
--- @field git_centers? table<any, blink-cmp-git.GCSOptions>
--- @field should_reload_items_cache? boolean|fun(): boolean|fun(): boolean
