local tags    = require("build.tags");
local ui      = require("build.ui");
local runner  = require("build.runner");
local symbols = require("build.symbols");

ui.Setup();
tags.Setup();
runner.Setup();
symbols.Setup();
