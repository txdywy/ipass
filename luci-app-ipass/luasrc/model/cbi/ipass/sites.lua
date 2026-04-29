local m
local s
local o

m = Map("ipass", translate("iPass - 站点配置"))
m.description = translate("管理需要从路由器检测连通性的站点。")

s = m:section(TypedSection, "site", translate("站点"))
s.addremove = true
s.anonymous = false
s.template = "cbi/tblsection"

o = s:option(Flag, "enabled", translate("启用"))
o.default = "1"
o.rmempty = false

o = s:option(Value, "name", translate("名称"))
o.placeholder = translate("Google 204")
o.rmempty = false

o = s:option(Value, "url", translate("URL"))
o.placeholder = "https://www.google.com/generate_204"
o.rmempty = false
o.validate = function(self, value, section)
	if value:match("^https?://[%w%.%-]+[:%d]*/?.*") then
		return value
	end
	return nil, translate("URL 必须以 http:// 或 https:// 开头")
end

o = s:option(Value, "category", translate("分类"))
o.placeholder = translate("国内")
o.default = translate("自定义")
o.rmempty = false

o = s:option(Value, "timeout", translate("超时秒数"))
o.datatype = "uinteger"
o.default = "5"
o.rmempty = false
o.validate = function(self, value, section)
	local n = tonumber(value)
	if n and n >= 1 and n <= 30 then
		return tostring(math.floor(n))
	end
	return nil, translate("超时秒数必须在 1 到 30 之间")
end

return m
