# blink-cmp-git

Git source for [blink.cmp](https://github.com/Saghen/blink.cmp)
completion plugin. This makes it possible to query pull requests, issues,
and users from GitHub. This is very useful when you are writing a commit with `nvime`.

Use `#` to search for issues and pull requests:

![blink-cmp-git pr and issues](./images/demo-prs-issues.png)

Use `:` to search for commits:

![blink-cmp-git commits](./images/demo-commits.png)

Use `@` to search for users:

![blink-cmp-git pr and issues](./images/demo-users.png)

## Requirements

`gh` is required for the default configuration.

[nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) is required.

## Installation

Add the plugin to your packer managers, and make sure it is loaded before `blink.cmp`.

### `lazy.nvim`

```lua
{
    'saghen/blink.cmp',
    dependencies = {
        {
            'Kaiser-Yang/blink-cmp-git',
            dependencies = { 'nvim-lua/plenary.nvim' }
        }
        -- ... other dependencies
    },
    opts = {
        sources = {
            -- add 'git' to the list
            default = { 'git', 'dictionary', 'lsp', 'path', 'luasnip', 'buffer' },
            git = {
                -- Because we use filetype to enable the source,
                -- we can make the score higher
                score_offset = 100,
                module = 'blink-cmp-git',
                name = 'Git',
                enabled = function()
                    -- enable the source when the filetype is gitcommit or markdown
                    return vim.o.filetype == 'gitcommit' or vim.o.filetype == 'markdown'
                end,
                --- @module 'blink-cmp-git'
                --- @type blink-cmp-git.Options
                opts = {
                    -- some options for the blink-cmp-git
                }
            },
        }
    }
}
```

## Configuration

There are some important options you may be interested in:

```lua
{
    --NOTE: because `gh` will get the result through the network, it may be slow.
    -- To use `async = true` and `use_items_cache = true` is recommended.

    -- Whether or not to run asynchronously
    async = true,
    -- whether or not to cache the items
    use_items_cache = true,
    -- When to reload the items cache
    should_reload_items_cache = false, -- or use a function
    git_centers = {
        -- For repositories whose centers are git hub, the name can be anything you want
        github = {
            mention = {
                -- When to enable the feature, by default,
                -- it is enabled when the `vim.fn.getcwd()` is a git repository
                -- whose remote contains `github.com`
                enable = remote_contains_github,
                -- After input `@`, the source will get the users from the repository
                triggers = { '@' },
                -- Command for getting the users
                get_command = 'gh',
                get_command_args = {
                    'api',
                    'repos/:owner/:repo/contributors',
                },
                -- The standard output will be parsed to this function
                -- This function must return a list of items
                separate_output = function(output)
                    local json_res = vim.json.decode(output)
                    local items = {}
                    for i = 1, #json_res do
                        items[i] = {
                            label = '@' .. json_field_helper(json_res[i].login),
                            insert_text = '@' .. json_field_helper(json_res[i].login),
                            -- For the documentation, you can use a string directly,
                            -- or return a `DocumentationCommand` defined in `types.lua` 
                            -- to get the documentation asynchronously
                            documentation = {
                                -- The command for getting the documentation
                                get_command = 'gh',
                                get_command_args = {
                                    'api',
                                    'users/' .. json_field_helper(json_res[i].login),
                                },
                                -- The output of the command will be parsed to this function
                                resolve_documentation = function(output)
                                    local user_info = vim.json.decode(output)
                                    return
                                        json_field_helper(user_info.login) ..
                                        ' ' .. json_field_helper(user_info.name) .. '\n' ..
                                        'Location: ' .. json_field_helper(user_info.location) .. '\n' ..
                                        'Email: ' .. json_field_helper(user_info.email) .. '\n' ..
                                        'Company: ' .. json_field_helper(user_info.company) .. '\n' ..
                                        'Created at: ' .. json_field_helper(user_info.created_at) .. '\n' ..
                                        'Updated at: ' .. json_field_helper(user_info.updated_at) .. '\n'
                                end
                            }
                        }
                    end
                    return items
                end,
            },
            -- ... Other features
        },
    }
```

Actually, `blink-cmp-git` can be used for any git centers, not just GitHub.
You can add more centers to the `git_centers` table. May in the future, I will add more centers,
such as `Git Lab` or `Gitee`.

See [default.lua](./lua/blink-cmp-git/default.lua) for the default configuration.

To see how I configured: [blink-cmp-git](https://github.com/Kaiser-Yang/dotfiles/blob/main/.config/nvim/lua/plugins/blink_cmp.lua).

## Performance

Once `async` is enabled, the completion will has no effect to your other operations.
How long it will take to show results depends on the network speed and the response time
of the git center. But, don't worries, once you enable `use_items_cache`, the items will be
cached when you first trigger the completion by inputting `@`, `#`, or `:`
(You can DIY the triggers). For the documentation of `mention` feature,
it will be cached when you hover on one item.

## Version Introduction

The release versions are something like `major.minor.patch`. When one of these numbers is increased:

* `patch`: bugs are fixed or docs are added. This will not break the compatibility.
* `minor`: compatible features are added. This may cause some configurations `deprecated`, but
not break the compatibility.
* `major`: incompatible features are added. All the `deprecated` configurations will be removed.
This will break the compatibility.

## Acknowledgment

Nice and fast completion plugin: [blink.cmp](https://github.com/Saghen/blink.cmp).

Inspired by [cmp-git](https://github.com/petertriho/cmp-git).
