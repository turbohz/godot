nushell := '/usr/bin/env nu'
export PROJECT_ROOT := justfile_directory()

_default:
	@just --choose

deps:
	#!{{nushell}}

	# Install dependencies to build in ArchLinux

	sudo pacman -Sy pkgconf embree3 freetype2 libglvnd libsquish libtheora libvorbis libvpx libwebp libwslay libxcursor libxi libxinerama libxrandr miniupnpc opusfile alsa-lib gcc pulseaudio yasm pipewire-alsa pipewire-pulse

check:
	./misc/scripts/file_format.sh

cleanup:
	#!{{nushell}}

	print "All uncommited changes will be lost!"

	input "Are you sure? (Press any key to continue)" --suppress-output

	# NOTICE: We use `X` so non-ignored files are excluded
	let candidates =  (git clean -dXn | lines | parse "Would remove {path}" | dfr into-df)

	# But we WANT to keep some ignored files!
	let excluded = (['.envrc','bin/','.vscode/'] | wrap path | dfr into-df)

	# Do the filtering
	let to_delete = ($candidates | dfr filter-with ($candidates | dfr into-df | dfr is-in $excluded | dfr not) | dfr into-nu)

	$to_delete | par-each { |r| (print $"🗑️  ($r.path)"; rm -r $r.path) }

	print $"Deleted ($to_delete | length) files."

merge:
	#!/bin/bash

	git checkout 3.x-custom
	git merge --no-ff --no-edit 3.x-custom-patches
	git merge --no-ff --no-edit 3.x-custom-tweaks
	git merge --no-ff --no-edit 3.x-custom-build
	git merge --no-ff --no-edit 3.x-custom-features

update:
	#!/bin/bash

	set -e

	git brach 3.x-custom-$(date '+%Y-%m-%d')
	git checkout upstream/3.x
	FROM=$(git rev-parse --short HEAD)
	echo "Rebase from: $FROM"
	git checkout 3.x-custom
	git fetch --no-recurse-submodules upstream
	git rebase --onto upstream/3.x "$FROM"

build what='tools':
	#!{{nushell}}
	SCONSFLAGS="-j8" just _build_{{what}}

_build_headless:
	#!{{nushell}}
	let FILENAME = "godot_server.x11.opt.tools.64"
	print $env.SCONSFLAGS
	scons platform=server target=release_debug linker=mold
	let ARTIFACT = $"($env.PROJECT_ROOT)/bin/($FILENAME)"
	strip $ARTIFACT
	ln -snf $ARTIFACT ~/bin/godot-headless

_build_android:
	#!{{nushell}}

	def fail [icon?:string='',msg:string='oops',code?:int=1] { $"**($icon)** ($msg)" | glow; exit $code }
	let namespace = "setrill"

	try {
		let-env SCRIPT_AES256_ENCRYPTION_KEY = (envchain $namespace nu -c "$env.SCRIPT_AES256_ENCRYPTION_KEY")
		if $env.SCRIPT_AES256_ENCRYPTION_KEY == "" { error }
	} catch {
		$env
		fail ⚠ $"($namespace)/SCRIPT_AES256_ENCRYPTION_KEY not found. Check `envchain` been properly configured."
	}

	let-env ANDROID_SDK_ROOT = $"($env.HOME)/Android/Sdk/"
	let-env ANDROID_HOME = $"($env.HOME)/Android/Sdk/"
	let platform = 'android'
	let profile = 'profiles/custom-template.py'
	let target = 'release'

	do {
		$"scons profile=($profile) platform=($platform) android_arch=armv7 target=($target)"
		$"scons profile=($profile) platform=($platform) android_arch=arm64v8 target=($target)"
		cd platform/android/java
		./gradlew generateGodotTemplates
	}
	# result
	ls -l bin/*.apk
