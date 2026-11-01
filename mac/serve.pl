#!/usr/bin/perl
# EV Quiz - tiny local web server for macOS (uses only the Perl that ships with macOS)
# Usage: perl mac/serve.pl <root dir> <port file>   -> prints the chosen port, then serves until killed
use strict; use warnings;
use IO::Socket::INET;
use File::Spec;
use Cwd qw(abs_path);

my $root = abs_path($ARGV[0] || '.');
my $portFile = $ARGV[1];
my %mime = (
  html => 'text/html; charset=utf-8', js => 'text/javascript; charset=utf-8', mjs => 'text/javascript; charset=utf-8',
  wasm => 'application/wasm', task => 'application/octet-stream', css => 'text/css', json => 'application/json',
  mp3 => 'audio/mpeg', data => 'application/octet-stream', tflite => 'application/octet-stream', binarypb => 'application/octet-stream', csv => 'text/csv; charset=utf-8', svg => 'image/svg+xml',
  png => 'image/png', ico => 'image/x-icon', md => 'text/plain; charset=utf-8', glb => 'model/gltf-binary',
);
$SIG{PIPE} = 'IGNORE';
$SIG{CHLD} = 'IGNORE';   # finished children are reaped automatically
$| = 1;

my ($srv, $port);
for my $p (8791 .. 8799) {
  $srv = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $p, Proto => 'tcp', Listen => 32, ReuseAddr => 1);
  if ($srv) { $port = $p; last; }
}
die "ERROR: no free port in 8791-8799\n" unless $srv;
if ($portFile) { open(my $f, '>', $portFile) or die; print $f $port; close $f; }
print "PORT $port\n";

sub reply {
  my ($c, $code, $type, $body, $extra, $len) = @_;   # $len: Content-Length for HEAD (body is empty)
  my $msg = $code == 200 ? 'OK' : $code == 206 ? 'Partial Content' : $code == 404 ? 'Not Found' : $code == 416 ? 'Range Not Satisfiable' : 'Bad Request';
  print $c "HTTP/1.1 $code $msg\r\nContent-Type: $type\r\nContent-Length: " . ($len // length($body)) .
    "\r\nAccept-Ranges: bytes\r\nCache-Control: no-cache\r\nConnection: close\r\n" . ($extra // '') . "\r\n";
  print $c $body;
}

# one child process per connection: Chrome opens spare connections that send nothing,
# and a single-threaded loop would wait on them forever
while (1) {
  my $c = $srv->accept or next;
  my $pid = fork;
  if (!defined $pid) { close $c; next; }
  if ($pid) { close $c; next; }
  close $srv;
  alarm 30;   # drop idle connections
  handle($c);
  exit 0;
}

sub handle {
  my ($c) = @_;
  binmode $c;
  my $line = <$c>;
  my ($hdr, $range); while (defined($hdr = <$c>)) { last if $hdr =~ /^\r?\n$/; $range = $1 if $hdr =~ /^Range:\s*bytes=(\d*-\d*)/i; }   # read the rest of the request headers
  unless (defined $line && $line =~ m{^(GET|HEAD) (\S+)}) { reply($c, 400, 'text/plain', '400') if defined $line; close $c; return; }
  my ($method, $path) = ($1, $2);
  $path =~ s/[?#].*//;
  $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;   # raw UTF-8 bytes, same as the file names on disk
  $path =~ s{^/+}{};
  $path = 'index.html' if $path eq '';
  my $full = File::Spec->catfile($root, $path);
  my $real = -f $full ? abs_path($full) : undef;
  if (!$real || index($real, $root . '/') != 0) {
    reply($c, 404, 'text/plain', '404');
    print "404 $path\n" unless $path eq 'favicon.ico';
    close $c; return;
  }
  my ($ext) = $real =~ /\.([^.\/]+)$/;
  my $type = $mime{lc($ext // '')} // 'application/octet-stream';
  if (open(my $fh, '<:raw', $real)) {
    local $/; my $body = <$fh>; close $fh;
    my $len = length($body);
    # Safari は音声（mp3）を Range（一部ずつ）で取りに来るので 206 で返す
    if (defined $range && $range =~ /^(\d*)-(\d*)$/ && ($1 ne '' || $2 ne '')) {
      my ($from, $to) = ($1, $2);
      if ($from eq '') { $from = $len - $to; $to = $len - 1; } elsif ($to eq '' || $to >= $len) { $to = $len - 1; }
      $from = 0 if $from < 0;
      if ($from > $to) { reply($c, 200, $type, $method eq 'HEAD' ? '' : $body, undef, $len); close $c; return; }   # invalid range -> ignore it
      if ($from >= $len) { reply($c, 416, 'text/plain', '', "Content-Range: bytes */$len\r\n"); close $c; return; }
      reply($c, 206, $type, $method eq 'HEAD' ? '' : substr($body, $from, $to - $from + 1), "Content-Range: bytes $from-$to/$len\r\n", $to - $from + 1);
    } else {
      reply($c, 200, $type, $method eq 'HEAD' ? '' : $body, undef, $len);
    }
  } else { reply($c, 404, 'text/plain', '404'); }
  close $c;
}
