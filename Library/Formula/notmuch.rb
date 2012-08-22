require 'formula'

class Notmuch < Formula
  homepage 'http://notmuchmail.org'
  url 'http://notmuchmail.org/releases/notmuch-0.14.tar.gz'
  sha1 'ad1ef9c2d29cfb0faab7837968d11325dee404bd'

  depends_on 'xapian'
  depends_on 'talloc'
  depends_on 'gmime'

  def install
    # requires a newer emacs than OS X provides, so disable the bindings
    system "./configure", "--prefix=#{prefix}", "--emacslispdir=#{ENV['HOME']}/.emacs.d/site-lisp/notmuch", "--emacsetcdir=#{ENV['HOME']}/.emacs.d/site-lisp/notmuch"
    system "make install"
    system "install_name_tool", "-change", "libnotmuch.2.dylib",
                                "#{lib}/libnotmuch.2.dylib", "#{bin}/notmuch"
  end
end
