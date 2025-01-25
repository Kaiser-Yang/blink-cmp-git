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
--- @field separate_output? fun(output: string): blink-cmp-git.CompletionItem[]
--- @field on_error? fun(return_value: number, standard_error: string): boolean

--- @class (exact) blink-cmp-git.GCSOptions
--- @field issue? blink-cmp-git.GCSCompletionOptions
--- @field pull_request? blink-cmp-git.GCSCompletionOptions
--- @field mention? blink-cmp-git.GCSCompletionOptions

--- @class (exact) blink-cmp-git.Options
--- @field async? boolean|fun(): boolean
--- @field use_items_cache? boolean|fun(): boolean
--- @field use_items_pre_cache? boolean|fun(): boolean
--- @field commit? blink-cmp-git.GCSCompletionOptions
--- @field git_centers? table<string, blink-cmp-git.GCSOptions>
