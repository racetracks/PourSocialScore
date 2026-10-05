-- Memory and speed of the recent-count layouts (3.2): A = one 144-place
-- ring per owner, B = 144 slots of { owner = count } plus a day total per
-- owner (the one PSS_ChatHistory.lua uses).   lua5.1 tools/harness/bench_recent.lua
local D = 144
-- A: owner-major ring { n, last, [1..144] }
local A = {}
function A.new() return {} end
local function rollA(t, cur)
	local last = t.last or cur
	if cur <= last then return end
	if cur - last >= D then for i=1,D do t[i]=nil end t.n=0 else
	for s=last+1,cur do local i=s%D+1 local c=t[i] if c then t.n=t.n-c t[i]=nil end end end
	t.last=cur
end
function A.add(r, o, cur) local t=r[o] if not t then t={n=0,last=cur} r[o]=t else rollA(t,cur) end local i=cur%D+1 t[i]=(t[i] or 0)+1 t.n=t.n+1 end
function A.get(r, o, cur) local t=r[o] if not t then return 0 end rollA(t,cur) return t.n end
-- B: time-major { last, day={o=n}, [1..144]={o=n} }
local B = {}
function B.new() return {day={}} end
local function rollB(r, cur)
	local last=r.last or cur
	if cur>last then local day=r.day
		for s=last+1,math.min(cur,last+D) do local i=s%D+1 local t=r[i] if t then for o,c in pairs(t) do local n=day[o]-c day[o]= n>0 and n or nil end r[i]=nil end end
	end
	r.last=cur
end
function B.add(r,o,cur) rollB(r,cur) local i=cur%D+1 local t=r[i] if not t then t={} r[i]=t end t[o]=(t[o] or 0)+1 r.day[o]=(r.day[o] or 0)+1 end
function B.get(r,o,cur) rollB(r,cur) return r.day[o] or 0 end

local keys={} for k=1,5000 do keys[k]="p:player"..k.."-realm" end
local function mem(f) collectgarbage('collect') collectgarbage('collect') local a=collectgarbage('count') local x=f() collectgarbage('collect') collectgarbage('collect') local b=collectgarbage('count') return b-a, x end
local scen = {
	{"1000 players blocked once", function(I,r) for k=1,1000 do I.add(r,keys[k],100+(k%144)) end end},
	{"1 filter, a block every slot", function(I,r) for s=1,144 do I.add(r,keys[1],s) end end},
	{"20 filters every slot + 500 one-offs", function(I,r) for s=1,144 do for f=1,20 do I.add(r,keys[f],s) end end for k=1,500 do I.add(r,keys[100+k],144) end end},
}
for _,sc in ipairs(scen) do
	for name,I in pairs({A=A,B=B}) do
		local kb = mem(function() local r=I.new() sc[2](I,r) return r end)
		local r=I.new() sc[2](I,r)
		local t0=os.clock() for n=1,200000 do I.get(r,keys[(n%20)+1],200) end
		local look=(os.clock()-t0)/200000*1e9
		-- writes in the same slot
		local r2=I.new() local t1=os.clock() for n=1,200000 do I.add(r2,keys[(n%50)+1],300) end
		local wr=(os.clock()-t1)/200000*1e9
		print(("%-38s %s  %7.1f KB  lookup %4.0f ns  write %4.0f ns"):format(sc[1],name,kb,look,wr))
	end
end
