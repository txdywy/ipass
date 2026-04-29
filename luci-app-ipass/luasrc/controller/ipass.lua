module("luci.controller.ipass", package.seeall)

local fs = require "nixio.fs"
local http = require "luci.http"
local jsonc = require "luci.jsonc"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

local function shell_quote(value)
	value = tostring(value or "")
	return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function read_sites()
	local sites = {}

	uci:foreach("ipass", "site", function(section)
		if section.enabled ~= "0" then
			sites[#sites + 1] = {
				id = section[".name"] or "",
				name = section.name or section[".name"] or "",
				url = section.url or "",
				category = section.category or "",
				enabled = section.enabled or "1",
				timeout = section.timeout or "5"
			}
		end
	end)

	return sites
end

local function run_site_check(site)
	local cmd = table.concat({
		"/usr/share/ipass/check.sh",
		shell_quote(site.name),
		shell_quote(site.url),
		shell_quote(site.category),
		shell_quote(site.enabled),
		shell_quote(site.timeout)
	}, " ")

	local output = sys.exec(cmd)
	local decoded = jsonc.parse(output)

	if type(decoded) ~= "table" then
		return {
			id = site.id,
			name = site.name,
			url = site.url,
			category = site.category,
			enabled = tonumber(site.enabled) or 1,
			timeout = tonumber(site.timeout) or 5,
			host = "",
			dns_ok = false,
			http_ok = false,
			ok = false,
			http_code = 0,
			time_total = 0,
			error_type = "internal_error",
			error_message = "检测脚本返回了无效结果",
			checked_at = os.date("%Y-%m-%d %H:%M:%S")
		}
	end

	decoded.id = site.id
	return decoded
end

function index()
	if not fs.access("/etc/config/ipass") then
		return
	end

	entry({"admin", "services", "ipass"}, template("ipass/status"), _("连通性检测"), 60).dependent = true
	entry({"admin", "services", "ipass", "sites"}, cbi("ipass/sites"), _("站点配置"), 61).leaf = true
	entry({"admin", "services", "ipass", "check"}, call("action_check")).leaf = true
end

function action_check()
	local results = {}
	local sites = read_sites()

	for _, site in ipairs(sites) do
		results[#results + 1] = run_site_check(site)
	end

	http.prepare_content("application/json")
	http.write_json({
		ok = true,
		count = #results,
		results = results
	})
end
