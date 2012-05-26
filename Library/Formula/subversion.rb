require 'formula'

def build_java?;      ARGV.include? "--java";   end
def build_perl?;      ARGV.include? "--perl";   end
def build_python?;    ARGV.include? "--python"; end
def build_ruby?;      ARGV.include? "--ruby";   end

class UniversalNeon < Requirement
  def message; <<-EOS.undent
      A universal build was requested, but neon was already built for a single arch.
      You may need to `brew rm neon` first.
    EOS
  end
  def satisfied?
    f = Formula.factory('neon')
    !f.installed? || archs_for_command(f.lib+'libneon.dylib').universal?
  end
end

class UniversalSqlite < Requirement
  def message; <<-EOS.undent
      A universal build was requested, but sqlite was already built for a single arch.
      You may need to `brew rm sqlite` first.
    EOS
  end
  def satisfied?
    f = Formula.factory('sqlite')
    !f.installed? || archs_for_command(f.lib+'libsqlite3.dylib').universal?
  end
end

class Subversion < Formula
  homepage 'http://subversion.apache.org/'
  url 'http://www.apache.org/dyn/closer.cgi?path=subversion/subversion-1.7.5.tar.bz2'
  sha1 '05c079762690d5ac1ccd2549742e7ef70fa45cf1'

  depends_on 'pkg-config' => :build

  # If Subversion can use the Lion versions of these, please
  # open an issue with a patch. Build against Homebrewed versions
  # for consistency. - @adamv
  depends_on 'neon'
  depends_on 'sqlite'

  if ARGV.build_universal?
    depends_on UniversalNeon.new
    depends_on UniversalSqlite.new
  end

  def options
    [
      ['--java', 'Build Java bindings.'],
      ['--perl', 'Build Perl bindings.'],
      ['--python', 'Build Python bindings.'],
      ['--ruby', 'Build Ruby bindings.'],
      ['--universal', 'Build as a Universal Intel binary.'],
    ]
  end

  def install
    if build_java?
      unless ARGV.build_universal?
        opoo "A non-Universal Java build was requested."
        puts "To use Java bindings with various Java IDEs, you might need a universal build:"
        puts "  brew install subversion --universal --java"
      end

      unless (ENV["JAVA_HOME"] or "").empty?
        opoo "JAVA_HOME is set. Try unsetting it if JNI headers cannot be found."
      end
    end

    ENV.universal_binary if ARGV.build_universal?

    # Use existing system zlib
    # Use dep-provided other libraries
    # Don't mess with Apache modules (since we're not sudo)
    args = ["--disable-debug",
            "--prefix=#{prefix}",
            "--with-ssl",
            "--with-zlib=/usr",
            "--with-sqlite=#{HOMEBREW_PREFIX}",
            # use our neon, not OS X's
            "--disable-neon-version-check",
            "--disable-mod-activation",
            "--without-apache-libexecdir",
            "--without-berkeley-db"]

    args << "--enable-javahl" << "--without-jikes" if build_java?
    args << "--with-ruby-sitedir=#{lib}/ruby" if build_ruby?

    # The system Python is built with llvm-gcc, so we override this
    # variable to prevent failures due to incompatible CFLAGS
    ENV['ac_cv_python_compile'] = ENV.cc

    system "./configure", *args
    system "make"
    system "make install"

    if build_python?
      system "make swig-py"
      system "make install-swig-py"
    end

    if build_perl?
      ENV.j1 # This build isn't parallel safe
      # Remove hard-coded ppc target, add appropriate ones
      if ARGV.build_universal?
        arches = "-arch x86_64 -arch i386"
      elsif MacOS.leopard?
        arches = "-arch i386"
      else
        arches = "-arch x86_64"
      end

      # Use version-appropriate system Perl
     if MacOS.leopard?
        perl_version = "5.8.8"
      else
        perl_version = "5.10.0"
      end

      inreplace "Makefile" do |s|
        s.change_make_var! "SWIG_PL_INCLUDES",
          "$(SWIG_INCLUDES) #{arches} -g -pipe -fno-common -DPERL_DARWIN -fno-strict-aliasing -I/usr/local/include -I/System/Library/Perl/#{perl_version}/darwin-thread-multi-2level/CORE"
      end
      system "make swig-pl"
      system "make install-swig-pl"
    end

    if build_java?
      ENV.j1 # This build isn't parallel safe
      system "make javahl"
      system "make install-javahl"
    end

    if build_ruby?
      ENV.j1 # This build isn't parallel safe
      system "make swig-rb"
      system "make install-swig-rb"
    end
  end

  def caveats
    s = ""

    if build_python?
      s += <<-EOS.undent
        You may need to add the Python bindings to your PYTHONPATH from:
          #{HOMEBREW_PREFIX}/lib/svn-python

      EOS
    end

    if build_ruby?
      s += <<-EOS.undent
        You may need to add the Ruby bindings to your RUBYLIB from:
          #{HOMEBREW_PREFIX}/lib/ruby

      EOS
    end

    if build_java?
      s += <<-EOS.undent
        You may need to link the Java bindings into the Java Extensions folder:
          sudo mkdir -p /Library/Java/Extensions
          sudo ln -s #{HOMEBREW_PREFIX}/lib/libsvnjavahl-1.dylib /Library/Java/Extensions/libsvnjavahl-1.dylib

      EOS
    end

    return s.empty? ? nil : s
  end
end
