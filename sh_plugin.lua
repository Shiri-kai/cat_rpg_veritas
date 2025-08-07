local PLUGIN = PLUGIN

PLUGIN.name = "Veritas RPG System"
PLUGIN.author = "The Cat"
PLUGIN.description = "Implements the Veritas RPG character and stat system."

ix.util.Include("sh_commands.lua")
ix.util.Include("sh_util.lua")

ix.util.Include("sv_hooks.lua")

ix.util.Include("cl_hooks.lua")

PLUGIN.veritasStats = {
	"strn", "rflx", "tghn", "intl", "tech", "prsn", "wyrd"
}


PLUGIN.initiativeQueue = {}
PLUGIN.initiativeTurnIndex = 1