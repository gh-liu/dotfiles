const COUNTRY_GROUPS = [
        ["HK", /(香港|港|Hong Kong|(?:^|[^a-z])HK(?:$|[^a-z]))/i],
        ["MO", /(澳门|澳門|Macau|(?:^|[^a-z])MO(?:$|[^a-z]))/i],
        ["TW", /(台湾|台灣|台北|台中|Taiwan|Taipei|(?:^|[^a-z])TW(?:$|[^a-z]))/i],
        ["JP", /(日本|川日|东京|東京|大阪|泉日|埼玉|沪日|深日|Japan|(?:^|[^a-z])JP(?:$|[^a-z]))/i],
        ["KR", /(韩国|韓國|首尔|首爾|韩|韓|Korea|(?:^|[^a-z])(?:KR|KOR)(?:$|[^a-z]))/i],
        [
                "US",
                /(美国|美國|波特兰|達拉斯|达拉斯|俄勒冈|凤凰城|费利蒙|硅谷|拉斯维加斯|洛杉矶|洛杉磯|圣何塞|圣克拉拉|西雅图|芝加哥|America|United States|(?:^|[^a-z])US(?:$|[^a-z]))/i,
        ],
        ["SG", /(新加坡|狮城|獅城|坡|Singapore|(?:^|[^a-z])SG(?:$|[^a-z]))/i],
        ["PH", /(菲律宾|菲律賓|菲|Philippines|(?:^|[^a-z])PH(?:$|[^a-z]))/i],
        ["MY", /(马来西亚|馬來西亞|马国|馬國|Malaysia|(?:^|[^a-z])MY(?:$|[^a-z]))/i],
        ["UK", /(英国|英國|伦敦|倫敦|United Kingdom|Britain|(?:^|[^a-z])(?:UK|GB)(?:$|[^a-z]))/i],
        ["FR", /(法国|法國|巴黎|France|(?:^|[^a-z])FR(?:$|[^a-z]))/i],
        ["IT", /(意大利|義大利|米兰|米蘭|罗马|羅馬|Italy|(?:^|[^a-z])IT(?:$|[^a-z]))/i],
        ["NL", /(荷兰|荷蘭|阿姆斯特丹|Netherlands|(?:^|[^a-z])NL(?:$|[^a-z]))/i],
        ["DE", /(德国|德國|柏林|法兰克福|法蘭克福|Germany|Deutschland|(?:^|[^a-z])DE(?:$|[^a-z]))/i],
];

const TEST_URL = "http://www.gstatic.com/generate_204";

const main = (config) => {
        console.log("🚀 脚本开始执行");

        config.proxies ??= [];
        config.mode = "rule";
        config.profile ??= {};
        config.profile["store-selected"] = true;

        const allProxyNames = config.proxies.map((p) => p.name);
        const groups = [];

        for (const [name, pattern] of COUNTRY_GROUPS) {
                const proxies = allProxyNames.filter((proxyName) => pattern.test(proxyName));

                if (proxies.length === 0) {
                        console.log(`⚠️ 国家代理组 [${name}] 未匹配到任何节点`);
                        continue;
                }

                groups.push({
                        name,
                        type: "url-test",
                        proxies,
                        url: TEST_URL,
                        interval: 600,
                        tolerance: 50,
                });
                console.log(`✅ 添加国家代理组：${name}（${proxies.length} 节点）`);
        }

        if (groups.length > 0) {
                const countryGroupNames = groups.map((group) => group.name);

                groups.unshift({
                        name: "Proxy",
                        type: "select",
                        proxies: countryGroupNames,
                });
                groups.splice(1, 0, {
                        name: "OpenAI",
                        type: "select",
                        proxies: ["Proxy", ...countryGroupNames, "DIRECT"],
                });
        }

        config["proxy-groups"] = groups;
        config["geox-url"] ??= {};
        config["geox-url"].asn ??=
                "https://github.com/xishang0128/geoip/releases/download/latest/GeoLite2-ASN.mmdb";
        config["rule-providers"] = {
                OpenAI: {
                        type: "http",
                        behavior: "classical",
                        format: "yaml",
                        url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/OpenAI/OpenAI_No_Resolve.yaml",
                        interval: 86400,
                },
                ASNChina: {
                        type: "http",
                        behavior: "classical",
                        format: "yaml",
                        url: "https://cdn.jsdelivr.net/gh/Kwisma/ASN-List@main/country/CN/CN_ASN_No_Resolve.yaml",
                        interval: 86400,
                },
        };

        const defaultPolicy = groups.some((group) => group.name === "Proxy") ? "Proxy" : "DIRECT";

        config.rules = [
                "DOMAIN,localhost,DIRECT",
                "DOMAIN-SUFFIX,local,DIRECT",
                "DOMAIN-SUFFIX,lan,DIRECT",
                "DOMAIN-SUFFIX,home.arpa,DIRECT",
                "IP-CIDR,10.0.0.0/8,DIRECT,no-resolve",
                "IP-CIDR,100.64.0.0/10,DIRECT,no-resolve",
                "IP-CIDR,127.0.0.0/8,DIRECT,no-resolve",
                "IP-CIDR,169.254.0.0/16,DIRECT,no-resolve",
                "IP-CIDR,172.16.0.0/12,DIRECT,no-resolve",
                "IP-CIDR,192.168.0.0/16,DIRECT,no-resolve",
                "IP-CIDR6,::1/128,DIRECT,no-resolve",
                "IP-CIDR6,fc00::/7,DIRECT,no-resolve",
                "IP-CIDR6,fe80::/10,DIRECT,no-resolve",
                "RULE-SET,OpenAI,OpenAI",
                "RULE-SET,ASNChina,DIRECT",
                "GEOIP,CN,DIRECT",
                `MATCH,${defaultPolicy}`,
        ];

        console.log("🎉 配置更新完成");
        return config;
};
