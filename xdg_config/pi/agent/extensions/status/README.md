# Status footer

The footer shows the current activity, model, session usage, and context usage.

The session name follows the Git branch, or the directory when there is no
branch, and refreshes on rename. The footer omits unnamed sessions, truncates
long names to 32 columns, and hides the session name before the branch on narrow
terminals.

## Usage totals

Token and cost totals include assistant messages, tool results, compactions,
branch summaries, and standalone `usage` entries such as background cache
warming. The footer sums reported input and output tokens and total costs
across providers. Output already includes reasoning tokens. The cache hit ratio
comes from the latest assistant request. Background costs appear on the next
normal snapshot refresh.
