using BinDeps

base_lib_dir = Pkg.dir("CxxWrap","deps","usr","lib")
@windows_only begin
	for libpath in [joinpath(base_lib_dir,"cxx_wrap.dll"), joinpath(base_lib_dir, "functions.dll")]
		if isfile(libpath)
			rm(libpath)
		end
	end
end

@linux_only begin
	for libpath in [joinpath(base_lib_dir,"libcxx_wrap.so"), joinpath(base_lib_dir, "libfunctions.so")]
		if isfile(libpath)
			rm(libpath)
		end
	end
end

@osx_only begin
	for libpath in [joinpath(base_lib_dir,"libcxx_wrap.dylib"), joinpath(base_lib_dir, "libfunctions.dylib")]
		if isfile(libpath)
			rm(libpath)
		end
	end
end


@windows_only push!(BinDeps.defaults, SimpleBuild)

@BinDeps.setup

function find_julia_lib(lib_suffix::AbstractString, julia_base_dir::AbstractString)
	julia_lib = joinpath(julia_base_dir, "lib", "julia", "libjulia.$lib_suffix")
	if !isfile(julia_lib)
		julia_lib = joinpath(julia_base_dir, "lib", "libjulia.$lib_suffix")
	end
	if !isfile(julia_lib)
		julia_lib = joinpath(julia_base_dir, "lib64", "julia", "libjulia.$lib_suffix")
	end
	if !isfile(julia_lib)
		julia_lib = joinpath(julia_base_dir, "lib", "x86_64-linux-gnu", "julia", "libjulia.$lib_suffix")
	end
	return julia_lib
end

# The base library, needed to wrap functions
cxx_wrap = library_dependency("cxx_wrap", aliases=["libcxx_wrap"])

prefix=joinpath(BinDeps.depsdir(cxx_wrap),"usr")
cxx_wrap_srcdir = joinpath(BinDeps.depsdir(cxx_wrap),"src","cxx_wrap")
cxx_wrap_builddir = joinpath(BinDeps.depsdir(cxx_wrap),"builds","cxx_wrap")
lib_prefix = @windows ? "" : "lib"
lib_suffix = @windows ? "dll" : (@osx? "dylib" : "so")
julia_base_dir = splitdir(JULIA_HOME)[1]
julia_lib = ""
for suff in ["dll", "dll.a", "dylib", "so"]
	julia_lib = find_julia_lib(suff, julia_base_dir)
	if isfile(julia_lib)
		break
	end
end

if !isfile(julia_lib)
	throw(ErrorException("Could not locate Julia library at $julia_lib"))
end

julia_include_dir = joinpath(julia_base_dir, "include", "julia")
if !isdir(julia_include_dir)  # then we're running directly from build
	julia_base_dir_aux = splitdir(splitdir(JULIA_HOME)[1])[1]  # useful for running-from-build
	julia_include_dir = joinpath(julia_base_dir_aux, "usr", "include" )
	julia_include_dir *= ";" * joinpath(julia_base_dir_aux, "src", "support" )
	julia_include_dir *= ";" * joinpath(julia_base_dir_aux, "src" )
end

# Set generator if on windows
genopt = "Unix Makefiles"
libdir_opt = ""
@windows_only begin
	if WORD_SIZE == 64
		genopt = "Visual Studio 14 2015 Win64"
	else
		genopt = "Visual Studio 14 2015"
		libdir_opt = "32"
	end
end

provides(BuildProcess,
	(@build_steps begin
		CreateDirectory(cxx_wrap_builddir)
		@build_steps begin
			ChangeDirectory(cxx_wrap_builddir)
			FileRule(joinpath(prefix,"lib$libdir_opt", "$(lib_prefix)cxx_wrap.$lib_suffix"),@build_steps begin
				`cmake -G "$genopt" -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_BUILD_TYPE="Release"  -DJULIA_INCLUDE_DIRECTORY="$julia_include_dir" -DJULIA_LIBRARY="$julia_lib" -DLIBDIR_SUFFIX=$libdir_opt $cxx_wrap_srcdir`
				`cmake --build . --config Release --target install`
			end)
		end
	end),cxx_wrap)

# Functions library for testing
examples = library_dependency("functions", aliases=["libfunctions"])

examples_srcdir = joinpath(BinDeps.depsdir(examples),"src","examples")
examples_builddir = joinpath(BinDeps.depsdir(examples),"builds","examples")
provides(BuildProcess,
	(@build_steps begin
		CreateDirectory(examples_builddir)
		@build_steps begin
			ChangeDirectory(examples_builddir)
			FileRule(joinpath(prefix,"lib$libdir_opt", "$(lib_prefix)functions.$lib_suffix"),@build_steps begin
				`cmake -G "$genopt" -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_BUILD_TYPE="Release" -DLIBDIR_SUFFIX=$libdir_opt $examples_srcdir`
				`cmake --build . --config Release --target install`
			end)
		end
	end),examples)

deps = [cxx_wrap, examples]
provides(Binaries, Dict(URI("https://github.com/barche/CxxWrap.jl/releases/download/v0.1.3/CxxWrap-julia-$(VERSION.major).$(VERSION.minor)-win$(WORD_SIZE).zip") => deps), os = :Windows)

@BinDeps.install

@windows_only pop!(BinDeps.defaults)
