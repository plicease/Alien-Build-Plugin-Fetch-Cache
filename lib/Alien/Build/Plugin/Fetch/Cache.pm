package Alien::Build::Plugin::Fetch::Cache;

use strict;
use warnings;
use 5.010;
use Alien::Build::Plugin;
use File::HomeDir 1.00;
use URI 1.71;
use Path::Tiny 0.100 ();
use Sereal 3.015 qw( encode_sereal decode_sereal );

# ABSTRACT: Alien::Build plugin to cache files downloaded from the internet
# VERSION

=head1 SYNOPSIS

 export ALIEN_BUILD_PRELOAD=Fetch::Cache

=head1 DESCRIPTION

This is a L<Alien::Build> plugin that caches the files that you download from
the internet, so that you only have to download them once.  Handy when doing
development of an L<Alien> distribution.  Not a particularly smart cache.
Doesn't ignore or expire old entries.  You have to remove them yourself.
They are stored in C<~/.alienbuild/plugin_fetch_cache>.

=head1 CAVEATS

As mentioned, not a sophisticated cache.  Patches welcome to make it smarter.
There are probably lots of corner cases that this plugin doesn't take into
account, but it is probably good enough for most Alien usage.

=cut

sub init
{
  my($self, $meta) = @_;
  
  $meta->around_hook(
    fetch => sub {
      my($orig, $build, $url) = @_;
      my $local_file;
      
      my $cache_url = $url // $build->meta_prop->{plugin_download_negotiate_default_url};
      
      if($cache_url && $cache_url !~ m!^/!  && $cache_url !~ m!^file:!)
      {
        my $uri = URI->new($cache_url);
        $local_file = Path::Tiny
                          ->new(File::HomeDir->my_home)
                          ->child('.alienbuild/plugin_fetch_cache')
                          ->child($uri->scheme)
                          ->child($uri->host)
                          ->child($uri->path)
                          ->child('meta');
        if(-r $local_file)
        {
          print "Alien::Build::Plugin::Fetch::Cache> using cached response for $uri\n";
          return decode_sereal($local_file->slurp_raw);
        }
      }
      my $res = $orig->($build, $url);
      
      if(defined $local_file)
      {
        $local_file->parent->mkpath;
        if($res->{type} eq 'file')
        {
          my $data = $local_file->sibling('data');
          my $res2 = {
            type     => 'file',
            filename => $res->{filename},
            path     => $data->stringify,
          };
          if($res->{content})
          {
            $data->spew_raw($res->{content});
          }
          elsif($res->{path})
          {
            Path::Tiny->new($res->{path})->copy($data);
          }
          else
          {
            die "got a file without contant or path";
          }
          $local_file->spew_raw( encode_sereal $res2 );
        }
        elsif($res->{type} =~ /^(list|html|dir_listing)$/)
        {
          $local_file->spew_raw( encode_sereal $res );
        }
      }
      
      $res;
    }
  );
}

1;

=head1 SEE ALSO

L<Alien::Build>, L<alienfile>, L<Alien::Base>

=cut