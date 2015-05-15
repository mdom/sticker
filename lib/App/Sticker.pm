package App::Sticker;

use strict;
use warnings;
use feature "state";

use App::Sticker::DB;
use Getopt::Long;
use Mojo::UserAgent;
use Mojo::DOM;
use Mojo::JSON 'decode_json';
use Mojo::ByteStream 'b';
use Mojo::Collection 'c';
use Path::Tiny;
use Moo;

has db       => ( is => 'lazy' );
has config   => ( is => 'lazy' );
has base_dir => ( is => 'lazy' );

sub _build_config {
    my $self           = shift;
    my %default_config = (
        stopwords => [
            qw(a about above after again against all am an and any are aren't as at
              be because been before being below between both but by can can't cannot
              could couldn't did didn't do does doesn't doing don't down during each
              few for from further had hadn't has hasn't have haven't having he he'd
              he'll he's her here here's hers herself him himself his how how's i i'd
              i'll i'm i've if in into is isn't it it's its itself let's me more most
              mustn't my myself no nor not of off on once only or other ought our
              ours ourselves out over own same shan't she she'd she'll she's should
              shouldn't so some such than that that's the their theirs them
              themselves then there there's these they they'd they'll they're they've
              this those through to too under until up use very was wasn't we we'd
              we'll we're we've were weren't what what's when when's where where's
              which while who who's whom why why's will with won't would wouldn't you
              you'd you'll you're you've your yours yourself yourselves)
        ],
        handler => [qw(iceweasel -new-tab)],
        worker  => 5,
    );

    my $config_file = $self->base_dir->child('config');
    my $config;
    if ( $config_file->exists ) {
        my $json = eval { decode_json( $config_file->slurp_utf8 ) };
        if ($json) {
            $config = { %default_config, %$json };
        }
    }
    return $config;
}

sub _build_db {
    my $self = shift;
    my $db = App::Sticker::DB->new( base_dir => $self->base_dir->child('url') );
    $db->create();
    return $db;
}

sub _build_base_dir {
    my $self     = shift;
    my $base_dir = path('~/.mbm/');
    $base_dir->mkpath();
    return $base_dir;
}

sub run {
    my $self     = shift;
    my $mode     = shift;
    my %dispatch = (
        add    => \&mode_add,
        import => \&mode_import,
        edit   => \&mode_edit,
        tag    => \&mode_tag,
        search => \&mode_search,
        open   => \&mode_open,
        delete => \&mode_delete,
    );

    if ( exists $dispatch{$mode} ) {
        my $sub = $dispatch{$mode};
        $self->$sub(@_);
    }
    else {
        die "$0: Unknown mode $mode\n";
    }
    exit 0;
}

sub mode_add {
    my ( $self, $url ) = @_;
    $self->add_urls( [$url] );
}

sub mode_import {
    my ( $self, $file ) = @_;
    my $content = path($file)->slurp_utf8;
    my $dom     = Mojo::DOM->new($content);
    my $urls =
      $dom->find('a["href"]')->map( attr => 'href' )->grep( sub { /^http/ } )
      ->to_array;
    $self->add_urls($urls);
}

sub mode_delete {
    my ( $self, $arg ) = @_;
    my $url = $self->to_url($arg);
    die "No url for $arg\n"
      if !$url;
    return $self->db->delete($url);
}

sub mode_edit {
    my ( $self, $arg ) = @_;
    my $url = $self->to_url($arg);
    die "No url for $arg\n"
      if !$url;
    my $file = $self->db->get_file($url);
    if ( $file->exists ) {
        my $editor = $ENV{EDITOR} ? $ENV{EDITOR} : 'vi';
        system( $editor , $file );
    }
    return;
}

sub mode_tag {
    my $self = shift;
    my ( $arg, @new_tags ) = @_;
    my $url = $self->to_url($arg);
    die "No url for $arg\n"
      if !$url;
    my @old_tags = b( $self->db->get( $url, 'tag' ) )->split(' ');
    return $self->db->set( $self->base_dir, $url, 'tag',
        c( @old_tags, @new_tags )->uniq );
}

sub mode_open {
    my $self = shift;
    my $arg  = shift;
    my $url  = $self->to_url($arg);
    die "No url for $arg\n"
      if !$url;
    return system( @{ $self->config->{handler} }, $url );
}

sub mode_search {
    my $self    = shift;
    my @terms   = @_ ? @_ : '';
    my $matches = $self->db->search( [qw(title url content)], $terms[0] );
    my $hist_fh = $self->base_dir->child('mbm_last_search')->openw_utf8();

    my $i   = 0;
    my $len = length(@$matches);
    for my $id (@$matches) {
        my $url   = $self->db->get( $id, 'url' );
        my $title = $self->db->get( $id, 'title' );
        my $line = sprintf( "%*d $url - $title", $len, ++$i );
        print b($line)->encode . "\n";
        print {$hist_fh} "$url\n";
    }
}

sub to_url {
    my ( $self, $url ) = @_;
    if ( $url =~ /\d+/ ) {
        my $last_search = $self->base_dir->child('mbm_last_search');
        if ( $last_search->exists ) {
            my @urls = $last_search->lines( { chomp => 1 } );
            $url = $urls[ $url - 1 ];
        }
    }
    $url = $self->normalize_url($url);
    return $url;
}

sub add_urls {
    my ( $self, $urls ) = @_;
    state $ua    = Mojo::UserAgent->new()->max_redirects(5);
    state $idle  = $self->config->{worker};
    state $delay = Mojo::IOLoop->delay();
    while ( $idle and my $url = shift @$urls ) {
        $url = $self->normalize_url($url);
        $idle--;
        my $cb = $delay->begin;
        $ua->get(
            $url => sub {
                my ( $ua, $tx ) = @_;
                $idle++;
                $self->process_tx( $tx, $url );

                # refresh worker pool
                $self->add_urls($urls);
                $cb->();
            }
        );
    }
    $delay->wait unless $delay->ioloop->is_running;
}

sub process_tx {
    my $self = shift;
    my ( $tx, $url ) = @_;
    if ( my $res = $tx->success ) {
        my ( $title, $content );
        my $dom = $res->dom;
        if ($dom) {
            $title = $dom->at('title');
            if ($title) {
                $title = b( $title->all_text() )->squish;
            }
            $dom->find('head')->map('remove');
            $dom->find('script')->map('remove');
            my %stopword =
              map { $_ => 1 } @{ $self->config->{stopwords} };

            ## There are many pages without a body-tag, so i just use all the
            ## text in the dom as content, TODO remove head before all_text()?

            $content = $dom->all_text();
            if ($content) {
                $content =
                  b($content)->squish->split(qr/[[:punct:][:space:]]+/)
                  ->map( sub        { lc } )
                  ->uniq->grep( sub { not exists $stopword{$_} } )
                  ->grep( sub       { length > 1 } )->join(' ');
            }
            else {
                warn "No words for $url\n";
            }
        }
        my $id = b($url)->sha1_sum;

        $self->db->set(
            $id,
            title   => $title   || '',
            content => $content || '',
            url     => $url
        );

    }
    else {
        my $err = $tx->error;
        print STDERR "Error for $url: ";
        if ( $err->{code} ) {
            warn "code $err->{code} response: $err->{message}\n";
        }
        else {
            warn "Connection error: $err->{message}\n";
        }

    }
}

sub normalize_url {
    my $self       = shift;
    my $url_string = shift;
    my $url        = Mojo::URL->new($url_string);
    ## If the user enters a url without a protocoll or a path, Mojo::URL parses
    ## the hostname as path.
    if ( not defined $url->host and defined $url->path ) {
        $url = Mojo::URL->new()->host( $url->path->trailing_slash(0) );
    }
    $url->scheme('http') if !$url->scheme;
    $url->authority('')  if !$url->authority;
    $url->port(undef)    if $url->port && $url->port == 80;
    $url->path('/')      if $url->path eq '';
    return $url;
}

1;
