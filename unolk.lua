local argparse = require("argparse")
local lfs = require("lfs")

local header = "i4I4i4i4"
--local header = "i4i4i4xxxxi4i4I4xxxx"
local entry = "i4i4"
--local entry = "i4i4I4xxxx"

local parser = argparse("unolk", "Extracts OLK archives.")
parser:argument("archive", "Path to the archive.")
parser:option("--file-list", "File list for naming files.")
parser:option("--output", "Path to output to"):default(".")
local args = parser:parse()

-- v0 code, just extract

local function is_olk(f)
	local hdat = f:read(header:packsize())
	local e = "<"
	if select(2, string.unpack("<"..header, hdat)) ~= 0x6B6E6C6F then
		e = ">"
		local mgk = select(2, string.unpack(">"..header, hdat))
		if mgk ~= 0x6B6E6C6F then
			return nil, mgk
		end
	end
	return e, hdat
end

local endian = {[">"] = "Big Endian", ["<"] = "Little Endian"}

local function extract_olk(f, path)
	if not lfs.attributes(path) then
		lfs.mkdir(path)
	end
	--local ecount, mgk, pad, arcoff, arcsize, arcdate = string.unpack(e..header, hdat)
	local e, mgk = is_olk(f)
	if not e then
		io.stderr:write(string.format("Error: bad magic! 0x%.8x != 0x6B6E6C6F\n", mgk))
		os.exit(1)
	end
	hdat = mgk
	local ecount, mgk, arcoff, arcsize = string.unpack(e..header, hdat)
	print(string.format("%d sub-files.", ecount))
	print(string.format("Archive Offset: %d", arcoff))
	print(string.format("Archive Size: %d", arcsize))
	--print(string.format("Archive Date: %s (no clue, hombre)", os.date("%c", arcdate)))
	local files = {}
	
	print("\nFiles:")
	for i=1, ecount do
		local enthead = f:read(entry:packsize())
		if not enthead or #enthead ~= entry:packsize() then
			io.stderr:write(string.format("Unexpected EOF! %i != %i\n", enthead and #enthead or -1, entry:packsize()))
			os.exit(1)
		end
		--local foff, fsize, fdate = string.unpack(e..entry, enthead)
		local foff, fsize = string.unpack(e..entry, enthead)
		local total_off = foff+arcoff
		local fname = string.format("%.8x", i)

		local fpath = path.."/"..fname
		--print(string.format("%s: %d byte offset, %d bytes, %s", fname, foff, fsize, os.date("%c", fdate)))
		print(string.format("%s.dat: %.8x byte offset, %.8x bytes", fname, total_off, fsize))
		--f:seek("cur", foff+fsize)
		local spot = f:seek("cur", 0)
		local out = io.open(fpath..".dat", "wb")
		f:seek("set", total_off)
		if is_olk(f) then
			print(string.format("%s.dat is an OLK!", fpath))
			table.insert(files, fpath)
		end
		f:seek("set", total_off)
		local dat = f:read(fsize)
		if not dat or #dat ~= fsize then
			io.stderr:write(string.format("Unexpected EOF! %i != %i\n", dat and #dat or -1, fsize))
		end
		out:write(dat)
		out:close()
		f:seek("set", spot)
	end
	print("")
	
	for i=1, #files do
		local nf = io.open(files[i]..".dat", "rb")
		extract_olk(nf, files[i])
	end
end

extract_olk(io.open(args.archive, "rb"), args.output)