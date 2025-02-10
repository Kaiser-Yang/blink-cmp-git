-- all empty strings in the table will be set to nil
return {
    url = "https://api.github.com/repos/Kaiser-Yang/blink-cmp-git/issues/30",
    repository_url = "https://api.github.com/repos/Kaiser-Yang/blink-cmp-git",
    labels_url = "https://api.github.com/repos/Kaiser-Yang/blink-cmp-git/issues/30/labels{/name}",
    comments_url = "https://api.github.com/repos/Kaiser-Yang/blink-cmp-git/issues/30/comments",
    events_url = "https://api.github.com/repos/Kaiser-Yang/blink-cmp-git/issues/30/events",
    html_url = "https://github.com/Kaiser-Yang/blink-cmp-git/issues/30",
    id = 2843947455,
    node_id = "I_kwDONn0LzM6pgzG_",
    number = 30,
    title = "feature request: notify when reloading cache",
    user = {
        login = "austinliuigi",
        id = 85013922,
        node_id = "MDQ6VXNlcjg1MDEzOTIy",
        avatar_url = "https://avatars.githubusercontent.com/u/85013922?v=4",
        gravatar_id = nil,
        url = "https://api.github.com/users/austinliuigi",
        html_url = "https://github.com/austinliuigi",
        followers_url = "https://api.github.com/users/austinliuigi/followers",
        following_url = "https://api.github.com/users/austinliuigi/following{/other_user}",
        gists_url = "https://api.github.com/users/austinliuigi/gists{/gist_id}",
        starred_url = "https://api.github.com/users/austinliuigi/starred{/owner}{/repo}",
        subscriptions_url = "https://api.github.com/users/austinliuigi/subscriptions",
        organizations_url = "https://api.github.com/users/austinliuigi/orgs",
        repos_url = "https://api.github.com/users/austinliuigi/repos",
        events_url = "https://api.github.com/users/austinliuigi/events{/privacy}",
        received_events_url = "https://api.github.com/users/austinliuigi/received_events",
        type = "User",
        user_view_type = "public",
        site_admin = false
    },
    labels = {},
    state = "open",
    locked = false,
    assignee = nil,
    assignees = {},
    milestone = nil,
    comments = 1,
    created_at = "2025-02-10T23:28:43Z",
    updated_at = "2025-02-11T01:26:34Z",
    closed_at = nil,
    author_association = "NONE",
    sub_issues_summary = {
        total = 0,
        completed = 0,
        percent_completed = 0
    },
    active_lock_reason = nil,
    body = [[
It would be nice if the user can get notified when a cache reload occurs. To do this, in the beginning of the `BlinkCmpGitReloadCache` callback, we can either:

1. Add `vim.notify("BlinkCmpGit: reloading cache")`
2. Fire a custom `BlinkCmpGitReloadPre` user autocommand and allow the user to add their own hook

https://github.com/Kaiser-Yang/blink-cmp-git/blob/0a0fc76045799bd9d46aaf0a0acffad3edbf7966/lua/blink-cmp-git/init.lua#L173-L182

On another note, I noticed that the autocommand that gets created is using the `BufEnter` event, but wouldn't it make more sense to use `DirChanged`?

https://github.com/Kaiser-Yang/blink-cmp-git/blob/0a0fc76045799bd9d46aaf0a0acffad3edbf7966/lua/blink-cmp-git/init.lua#L183-L192

Thanks for the great plugin :)
]],
    closed_by = nil,
    reactions = {
        url = "https://api.github.com/repos/Kaiser-Yang/blink-cmp-git/issues/30/reactions",
        total_count = 0,
        ["+1"] = 0,
        ["-1"] = 0,
        laugh = 0,
        hooray = 0,
        confused = 0,
        heart = 0,
        rocket = 0,
        eyes = 0
    },
    timeline_url = "https://api.github.com/repos/Kaiser-Yang/blink-cmp-git/issues/30/timeline",
    performed_via_github_app = nil,
    state_reason = nil
}
