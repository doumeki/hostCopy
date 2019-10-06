local n=require"nixio.fs"
local r=require"luci.sys"
local a=require"luci.util"
local e=require"luci.http"
local f=require"nixio",require"nixio.util"
module("luci.dispatcher",package.seeall)
context=a.threadlocal()
uci=require"luci.model.uci"
i18n=require"luci.i18n"
_M.fs=n
local h=nil
local t
function build_url(...)
local a={...}
local e={e.getenv("SCRIPT_NAME")or""}
local t
for a,t in ipairs(a)do
if t:match("^[a-zA-Z0-9_%-%.%%/,;]+$")then
e[#e+1]="/"
e[#e+1]=t
end
end
if#a==0 then
e[#e+1]="/"
end
return table.concat(e,"")
end
function _ordered_children(t)
local a,a,e=nil,nil,{}
for a,t in pairs(t.nodes)do
e[#e+1]={
name=a,
node=t,
order=t.order or 100
}
end
table.sort(e,function(e,t)
if e.order==t.order then
return e.name<t.name
else
return e.order<t.order
end
end)
return e
end
function node_visible(e)
if e then
return not(
(not e.title or#e.title==0)or
(not e.target or e.hidden==true)or
(type(e.target)=="table"and e.target.type=="firstchild"and
(type(e.nodes)~="table"or not next(e.nodes)))
)
end
return false
end
function node_childs(t)
local e={}
if t then
local a,a
for a,t in ipairs(_ordered_children(t))do
if node_visible(t.node)then
e[#e+1]=t.name
end
end
end
return e
end
function error404(t)
e.status(404,"Not Found")
t=t or"Not Found"
local function o()
local e=require"luci.template"
e.render("error404")
end
if not a.copcall(o)then
e.prepare_content("text/plain")
e.write(t)
end
return false
end
function error500(t)
a.perror(t)
if not context.template_header_sent then
e.status(500,"Internal Server Error")
e.prepare_content("text/plain")
e.write(t)
else
require("luci.template")
if not a.copcall(luci.template.render,"error500",{message=t})then
e.prepare_content("text/plain")
e.write(t)
end
end
return false
end
function httpdispatch(o,i)
e.context.request=o
local t={}
context.request=t
local o=e.urldecode(o:getenv("PATH_INFO")or"",true)
if i then
for a,e in ipairs(i)do
t[#t+1]=e
end
end
local i
for e in o:gmatch("[^/%z]+")do
t[#t+1]=e
end
local t,t=a.coxpcall(function()
dispatch(context.request)
end,error500)
e.close()
end
local function y(t)
if type(t)=="table"then
if type(t.post)=="table"then
local o,o,a
for o,t in pairs(t.post)do
a=e.formvalue(o)
if(type(t)=="string"and
a~=t)or
(t==true and a==nil)
then
return false
end
end
return true
end
return(t.post==true)
end
return false
end
function test_post_security()
if e.getenv("REQUEST_METHOD")~="POST"then
e.status(405,"Method Not Allowed")
e.header("Allow","POST")
return false
end
if e.formvalue("token")~=context.authtoken then
e.status(403,"Forbidden")
luci.template.render("csrftoken")
return false
end
return true
end
local function m(t,o)
local e=a.ubus("session","get",{ubus_rpc_session=t})
if type(e)=="table"and
type(e.values)=="table"and
type(e.values.token)=="string"and
(not o or
a.contains(o,e.values.username))
then
uci:set_session_id(t)
return t,e.values
end
return nil,nil
end
local function w(o,t,i)
if a.contains(i,o)then
local t=a.ubus("session","login",{
username=o,
password=t,
timeout=tonumber(luci.config.sauth.sessiontime)
})
local i=context.requestpath
and table.concat(context.requestpath,"/")or""
if type(t)=="table"and
type(t.ubus_rpc_session)=="string"
then
a.ubus("session","set",{
ubus_rpc_session=t.ubus_rpc_session,
values={token=r.uniqueid(16)}
})
io.stderr:write("luci: accepted login on /%s for %s from %s\n"
%{i,o,e.getenv("REMOTE_ADDR")or"?"})
return m(t.ubus_rpc_session)
end
io.stderr:write("luci: failed login on /%s for %s from %s\n"
%{i,o,e.getenv("REMOTE_ADDR")or"?"})
end
return nil,nil
end
function dispatch(s)
local o=context
o.path=s
local i=require"luci.config"
assert(i.main,
"/etc/config/luci seems to be corrupt, unable to find section 'main'")
local l=require"luci.i18n"
local t=i.main.lang or"auto"
if t=="auto"then
local e=e.getenv("HTTP_ACCEPT_LANGUAGE")or""
for a in e:gmatch("[%w_-]+")do
local e,o=a:match("^([a-z][a-z])[_-]([a-zA-Z][a-zA-Z])$")
if e and o then
local a="%s_%s"%{e,o:lower()}
if i.languages[a]then
t=a
break
elseif i.languages[e]then
t=e
break
end
elseif i.languages[a]then
t=a
break
end
end
end
if t=="auto"then
t=l.default
end
l.setlanguage(t)
local t=o.tree
local i
if not t then
t=createtree()
end
local i={}
local h={}
o.args=h
o.requestargs=o.requestargs or h
local c
local u={}
local d={}
for o,e in ipairs(s)do
u[#u+1]=e
d[#d+1]=e
t=t.nodes[e]
c=o
if not t then
break
end
a.update(i,t)
if t.leaf then
break
end
end
if t and t.leaf then
for e=c+1,#s do
h[#h+1]=s[e]
d[#d+1]=s[e]
end
end
o.requestpath=o.requestpath or d
o.path=u
if(t and t.index)or not i.notemplate then
local t=require("luci.template")
local i=i.mediaurlbase or luci.config.main.mediaurlbase
if not pcall(t.Template,"themes/%s/header"%n.basename(i))then
i=nil
for a,e in pairs(luci.config.themes)do
if a:sub(1,1)~="."and pcall(t.Template,
"themes/%s/header"%n.basename(e))then
i=e
end
end
assert(i,"No valid theme found")
end
local function s(i,o,e,n)
if i then
local t=getfenv(3)
local i=(type(t.self)=="table")and t.self
if type(e)=="table"then
if not next(e)then
return''
else
e=a.serialize_json(e)
end
end
e=tostring(e or
(type(t[o])~="function"and t[o])or
(i and type(i[o])~="function"and i[o])or"")
if n~=true then
e=a.pcdata(e)
end
return string.format(' %s="%s"',tostring(o),e)
else
return''
end
end
t.context.viewns=setmetatable({
write=e.write;
include=function(e)t.Template(e):render(getfenv(2))end;
translate=l.translate;
translatef=l.translatef;
export=function(e,a)if t.context.viewns[e]==nil then t.context.viewns[e]=a end end;
striptags=a.striptags;
pcdata=a.pcdata;
media=i;
theme=n.basename(i);
resource=luci.config.main.resourcebase;
ifattr=function(...)return s(...)end;
attr=function(...)return s(true,...)end;
url=build_url;
},{__index=function(a,t)
if t=="controller"then
return build_url()
elseif t=="REQUEST_URI"then
return build_url(unpack(o.requestpath))
elseif t=="FULL_REQUEST_URI"then
local t={e.getenv("SCRIPT_NAME")or"",e.getenv("PATH_INFO")}
local e=e.getenv("QUERY_STRING")
if e and#e>0 then
t[#t+1]="?"
t[#t+1]=e
end
return table.concat(t,"")
elseif t=="token"then
return o.authtoken
else
return rawget(a,t)or _G[t]
end
end})
end
i.dependent=(i.dependent~=false)
assert(not i.dependent or not i.auto,
"Access Violation\nThe page at '"..table.concat(s,"/").."/' "..
"has no parent node so the access to this location has been denied.\n"..
"This is a software bug, please report this message at "..
"https://github.com/openwrt/luci/issues"
)
if i.sysauth and not o.authsession then
local a=i.sysauth_authenticator
local d,t,n,h,s
if type(a)=="string"and a~="htmlauth"then
error500("Unsupported authenticator %q configured"%a)
return
end
if type(i.sysauth)=="table"then
h,s=nil,i.sysauth
else
h,s=i.sysauth,{i.sysauth}
end
if type(a)=="function"then
d,t=a(r.user.checkpasswd,s)
else
t=e.getcookie("sysauth")
end
t,n=m(t,s)
if not(t and n)and a=="htmlauth"then
local a=e.getenv("HTTP_AUTH_USER")
local r=e.getenv("HTTP_AUTH_PASS")
if a==nil and r==nil then
a=e.formvalue("luci_username")
r=e.formvalue("luci_password")
end
t,n=w(a,r,s)
if not t then
local t=require"luci.template"
context.path={}
e.status(403,"Forbidden")
e.header("X-LuCI-Login-Required","yes")
t.render(i.sysauth_template or"sysauth",{
duser=h,
fuser=a
})
return
end
e.header("Set-Cookie",'sysauth=%s; path=%s; HttpOnly%s'%{
t,'/',e.getenv("HTTPS")=="on"and"; secure"or""
})
e.redirect(build_url(unpack(o.requestpath)))
end
if not t or not n then
e.status(403,"Forbidden")
e.header("X-LuCI-Login-Required","yes")
return
end
o.authsession=t
o.authtoken=n.token
o.authuser=n.username
end
if i.cors and e.getenv("REQUEST_METHOD")=="OPTIONS"then
luci.http.status(200,"OK")
luci.http.header("Access-Control-Allow-Origin",e.getenv("HTTP_ORIGIN")or"*")
luci.http.header("Access-Control-Allow-Methods","GET, POST, OPTIONS")
return
end
if t and y(t.target)then
if not test_post_security(t)then
return
end
end
if i.setgroup then
r.process.setgroup(i.setgroup)
end
if i.setuser then
r.process.setuser(i.setuser)
end
local e=nil
if t then
if type(t.target)=="function"then
e=t.target
elseif type(t.target)=="table"then
e=t.target.target
end
end
if t and(t.index or type(e)=="function")then
o.dispatched=t
o.requested=o.requested or o.dispatched
end
if t and t.index then
local e=require"luci.template"
if a.copcall(e.render,"indexer",{})then
return true
end
end
if type(e)=="function"then
a.copcall(function()
local a=getfenv(e)
local t=require(t.module)
local t=setmetatable({},{__index=
function(o,e)
return rawget(o,e)or t[e]or a[e]
end})
setfenv(e,t)
end)
local o,i
if type(t.target)=="table"then
o,i=a.copcall(e,t.target,unpack(h))
else
o,i=a.copcall(e,unpack(h))
end
if not o then
error500("Failed to execute "..(type(t.target)=="function"and"function"or t.target.type or"unknown")..
" dispatcher target for entry '/"..table.concat(s,"/").."'.\n"..
"The called action terminated with an exception:\n"..tostring(i or"(unknown)"))
end
else
local e=node()
if not e or not e.target then
error404("No root node was registered, this usually happens if no module was installed.\n"..
"Install luci-mod-admin-full and retry. "..
"If the module is already installed, try removing the /tmp/luci-indexcache file.")
else
error404("No page is registered at '/"..table.concat(s,"/").."'.\n"..
"If this url belongs to an extension, make sure it is properly installed.\n"..
"If the extension was recently installed, try removing the /tmp/luci-indexcache file.")
end
end
end
function createindex()
local e={}
local o="%s/controller/"%a.libpath()
local t,t
for t in(n.glob("%s*.lua"%o)or function()end)do
e[#e+1]=t
end
for t in(n.glob("%s*/*.lua"%o)or function()end)do
e[#e+1]=t
end
if indexcache then
local a=n.stat(indexcache,"mtime")
if a then
local t=0
for a,e in ipairs(e)do
local e=n.stat(e,"mtime")
t=(e and e>t)and e or t
end
if a>t and r.process.info("uid")==0 then
assert(
r.process.info("uid")==n.stat(indexcache,"uid")
and n.stat(indexcache,"modestr")=="rw-------",
"Fatal: Indexcache is not sane!"
)
h=loadfile(indexcache)()
return h
end
end
end
h={}
for t,e in ipairs(e)do
local t="luci.controller."..e:sub(#o+1,#e-4):gsub("/",".")
local a=require(t)
assert(a~=true,
"Invalid controller file found\n"..
"The file '"..e.."' contains an invalid module line.\n"..
"Please verify whether the module name is set to '"..t..
"' - It must correspond to the file path!")
local a=a.index
assert(type(a)=="function",
"Invalid controller file found\n"..
"The file '"..e.."' contains no index() function.\n"..
"Please make sure that the controller contains a valid "..
"index function and verify the spelling!")
h[t]=a
end
if indexcache then
local e=f.open(indexcache,"w",600)
e:writeall(a.get_bytecode(h))
e:close()
end
end
function createtree()
if not h then
createindex()
end
local e=context
local t={nodes={},inreq=true}
e.treecache=setmetatable({},{__mode="v"})
e.tree=t
local a=setmetatable({},{__index=luci.dispatcher})
for t,e in pairs(h)do
a._NAME=t
setfenv(e,a)
e()
end
return t
end
function assign(e,t,o,a)
local e=node(unpack(e))
e.nodes=nil
e.module=nil
e.title=o
e.order=a
setmetatable(e,{__index=_create_node(t)})
return e
end
function entry(e,a,o,t)
local e=node(unpack(e))
e.target=a
e.title=o
e.order=t
e.module=getfenv(2)._NAME
return e
end
function get(...)
return _create_node({...})
end
function node(...)
local e=_create_node({...})
e.module=getfenv(2)._NAME
e.auto=nil
return e
end
function lookup(...)
local t,e=nil,{}
for t=1,select('#',...)do
local a,t=nil,tostring(select(t,...))
for t in t:gmatch("[^/]+")do
e[#e+1]=t
end
end
for a=#e,1,-1 do
local t=context.treecache[table.concat(e,".",1,a)]
if t and(a==#e or t.leaf)then
return t,build_url(unpack(e))
end
end
end
function _create_node(t)
if#t==0 then
return context.tree
end
local o=table.concat(t,".")
local e=context.treecache[o]
if not e then
local a=table.remove(t)
local i=_create_node(t)
e={nodes={},auto=true,inreq=true}
local n,n
for t,a in ipairs(t)do
if context.path[t]~=a then
e.inreq=false
break
end
end
e.inreq=e.inreq and(context.path[#t+1]==a)
i.nodes[a]=e
context.treecache[o]=e
end
return e
end
function _find_eligible_node(t,o,e,i,s)
local n=_ordered_children(t)
if not t.leaf and e~=nil then
local a={unpack(o)}
if e==false then
e=nil
end
local t,t
for n,t in ipairs(n)do
a[#o+1]=t.name
local e=_find_eligible_node(t.node,a,
e,i,true)
if e then
return e
end
end
end
if s and
(not i or
(type(t.target)=="table"and
a.contains(i,t.target.type)))
then
return o
end
end
function _find_node(t,a)
local e={unpack(context.path)}
local o=table.concat(e,".")
local o=context.treecache[o]
e=_find_eligible_node(o,e,t,a)
if e then
dispatch(e)
else
require"luci.template".render("empty_node_placeholder")
end
end
function _firstchild()
return _find_node(false,nil)
end
function firstchild()
return{type="firstchild",target=_firstchild}
end
function _firstnode()
return _find_node(true,{"cbi","form","template","arcombine"})
end
function firstnode()
return{type="firstnode",target=_firstnode}
end
function alias(...)
local e={...}
return function(...)
for a,t in ipairs({...})do
e[#e+1]=t
end
dispatch(e)
end
end
function rewrite(t,...)
local o={...}
return function(...)
local e=a.clone(context.dispatched)
for t=1,t do
table.remove(e,1)
end
for a,t in ipairs(o)do
table.insert(e,a,t)
end
for a,t in ipairs({...})do
e[#e+1]=t
end
dispatch(e)
end
end
local function o(t,...)
local e=getfenv()[t.name]
assert(e~=nil,
'Cannot resolve function "'..t.name..'". Is it misspelled or local?')
assert(type(e)=="function",
'The symbol "'..t.name..'" does not refer to a function but data '..
'of type "'..type(e)..'".')
if#t.argv>0 then
return e(unpack(t.argv),...)
else
return e(...)
end
end
function call(e,...)
return{type="call",argv={...},name=e,target=o}
end
function post_on(e,t,...)
return{
type="call",
post=e,
argv={...},
name=t,
target=o
}
end
function post(...)
return post_on(true,...)
end
local t=function(e,...)
require"luci.template".render(e.view)
end
function template(e)
return{type="template",view=e,target=t}
end
local function d(n,...)
local s=require"luci.cbi"
local h=require"luci.template"
local o=require"luci.http"
local t=n.config or{}
local i=s.load(n.model,...)
local e=nil
local r,r
for i,o in ipairs(i)do
if a.instanceof(o,s.SimpleForm)then
io.stderr:write("Model %s returns SimpleForm but is dispatched via cbi(),\n"
%n.model)
io.stderr:write("please change %s to use the form() action instead.\n"
%table.concat(context.request,"/"))
end
o.flow=t
local t=o:parse()
if t and(not e or t<e)then
e=t
end
end
local function a(e)
return type(e)=="table"and build_url(unpack(e))or e
end
if t.on_valid_to and e and e>0 and e<2 then
o.redirect(a(t.on_valid_to))
return
end
if t.on_changed_to and e and e>1 then
o.redirect(a(t.on_changed_to))
return
end
if t.on_success_to and e and e>0 then
o.redirect(a(t.on_success_to))
return
end
if t.state_handler then
if not t.state_handler(e,i)then
return
end
end
o.header("X-CBI-State",e or 0)
if not t.noheader then
h.render("cbi/header",{state=e})
end
local o
local a
local r=false
local n=true
local s={}
for t,e in ipairs(i)do
if e.apply_needed and e.parsechain then
local t
for t,e in ipairs(e.parsechain)do
s[#s+1]=e
end
r=true
end
if e.redirect then
o=o or e.redirect
end
if e.pageaction==false then
n=false
end
if e.message then
a=a or{}
a[#a+1]=e.message
end
end
for e,t in ipairs(i)do
t:render({
firstmap=(e==1),
redirect=o,
messages=a,
pageaction=n,
parsechain=s
})
end
if not t.nofooter then
h.render("cbi/footer",{
flow=t,
pageaction=n,
redirect=o,
state=e,
autoapply=t.autoapply,
trigger_apply=r
})
end
end
function cbi(e,t)
return{
type="cbi",
post={["cbi.submit"]=true},
config=t,
model=e,
target=d
}
end
local function o(e,...)
local a={...}
local t=#a>0 and e.targets[2]or e.targets[1]
setfenv(t.target,e.env)
t:target(unpack(a))
end
function arcombine(e,t)
return{type="arcombine",env=getfenv(),target=o,targets={e,t}}
end
local function i(e,...)
local t=require"luci.cbi"
local o=require"luci.template"
local i=require"luci.http"
local a=luci.cbi.load(e.model,...)
local e=nil
local t,t
for a,t in ipairs(a)do
local t=t:parse()
if t and(not e or t<e)then
e=t
end
end
i.header("X-CBI-State",e or 0)
o.render("header")
for t,e in ipairs(a)do
e:render()
end
o.render("footer")
end
function form(e)
return{
type="cbi",
post={["cbi.submit"]=true},
model=e,
target=i
}
end
translate=i18n.translate
function _(e)
return e
end
