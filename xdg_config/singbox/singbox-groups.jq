def subc_nodes:
  .outbounds;

def base_config:
  $base[0];

def groups: [
  {tag: "HK", regex: "(?i)(港|HK|Hong)"},
  {tag: "MO", regex: "(?i)(澳门|澳門|Macau|\\bMO\\b)"},
  {tag: "TW", regex: "(?i)(台|TW|Tai)"},
  {tag: "JP", regex: "(?i)(日本|川日|东京|大阪|泉日|埼玉|沪日|深日|JP|Japan)"},
  {tag: "KR", regex: "(?i)(KR|Korea|KOR|首尔|韩|韓)"},
  {tag: "US", regex: "(?i)(美国|波特兰|达拉斯|俄勒冈|凤凰城|费利蒙|硅谷|拉斯维加斯|洛杉矶|圣何塞|圣克拉拉|西雅图|芝加哥|US|America|United States)"},
  {tag: "SG", regex: "(?i)(新加坡|坡|狮城|SG|Singapore)"},
  {tag: "PH", regex: "(?i)(菲律宾|菲|PH|Philippines)"},
  {tag: "DE", regex: "(?i)(德|DE|Germany)"},
  {tag: "UK", regex: "(?i)(英|GB|United Kingdom|United Kindom)"},
  {tag: "MY", regex: "(?i)(马国|MY|Malaysia)"}
];

def group_urltests:
  [
    groups[] as $group
    | [subc_nodes[] | select(.tag | test($group.regex)) | .tag] as $tags
    | select($tags | length > 0)
    | {
        type: "urltest",
        tag: $group.tag,
        outbounds: $tags,
        url: "https://www.gstatic.com/generate_204",
        interval: "10m"
      }
  ];

def group_tags($groups):
  $groups | map(.tag);

. as $subc
| group_urltests as $groups
| group_tags($groups) as $proxy_outbounds
| base_config
| .outbounds = (
    (.outbounds | map(if .tag == "proxy" then . + {
      outbounds: $proxy_outbounds,
      default: ($proxy_outbounds[0] // "direct")
    } else . end))
    + $groups
    + ($subc.outbounds // [])
  )
