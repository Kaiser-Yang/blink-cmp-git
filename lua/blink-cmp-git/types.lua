--- @class (exact) blink-cmp-git.DocumentationCommand
--- @field get_token? string|fun(): string
--- @field get_command string|fun(): string
--- @field get_command_args string[]|fun(command:string, token: string): string[]
--- @field resolve_documentation fun(output: string): string

--- @class (exact) blink-cmp-git.CompletionItem
--- @field label string
--- @field kind_name string
--- @field insert_text string
--- @field score_offset? number
--- @field documentation string|blink-cmp-git.DocumentationCommand

--- @class (exact) blink-cmp-git.GCSCompletionOptions
--- @field enable? boolean|fun(): boolean
--- @field triggers? string[]|fun(): string[]
--- @field get_token? string|fun(): string
--- @field get_command? string|fun(): string
--- @field get_command_args? string[]|fun(command:string, token: string): string[]
--- @field insert_text_trailing? string|fun(): string
--- @field separate_output? fun(output: string): any[]
--- @field get_label? fun(item: any): string
--- @field get_kind_name? fun(item: any): string
--- @field get_insert_text? fun(item: any): string
--- @field get_documentation? fun(item: any): string|blink-cmp-git.DocumentationCommand
--- @field configure_score_offset? fun(items: blink-cmp-git.CompletionItem[])
--- @field on_error? fun(return_value: number, standard_error: string): boolean

--- @class (exact) blink-cmp-git.GCSOptions
--- @field issue? blink-cmp-git.GCSCompletionOptions
--- @field pull_request? blink-cmp-git.GCSCompletionOptions
--- @field mention? blink-cmp-git.GCSCompletionOptions

--- @alias blink-cmp-git.GCSGitCenterKeys 'github'|'gitlab'|string

--- @class (exact) blink-cmp-git.Options
--- @field async? boolean|fun(): boolean
--- @field use_items_cache? boolean|fun(): boolean
--- @field use_items_pre_cache? boolean|fun(): boolean
--- @field should_reload_cache? fun(): boolean
--- @field kind_icons? table<string, string>
--- @field commit? blink-cmp-git.GCSCompletionOptions
--- @field git_centers? table<blink-cmp-git.GCSGitCenterKeys, blink-cmp-git.GCSOptions>
