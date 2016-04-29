package App::Sticker::Command;
use Mojo::Base -base;

use App::Sticker::URLQueue;
use Mojo::SQLite;
use Mojo::SQLite::Migrations;
use Mojo::ByteStream 'b';
use Path::Tiny;
use Config::Tiny;

has config_file => sub {
    return
      $ENV{STICKER_CONFIG_DIR} ? path( $ENV{STICKER_CONFIG_DIR} )
      : path(
          $ENV{XDG_CONFIG_HOME} ? $ENV{XDG_CONFIG_HOME}
        : $^O eq "MSWin32"      ? $ENV{APPDATA}
        : $^O eq 'darwin'       ? '~/Library/Application Support'
        :                         '~/.config/'
      )->child('sticker')->child('config')->stringify;
};

has ua => sub {
    my $self = shift;
    App::Sticker::URLQueue->new( worker => $self->config->{worker} );
};

has sql => sub {
    my $self = shift;
    Mojo::SQLite->new( $self->config->{db_file} );
};

has stopwords => sub {
    [
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
    ];
};

has config => sub {
    my $self     = shift;
    my %defaults = (
        url_viewer => 'xdg-open %s',
        worker     => 16,
        db_file    => $self->_build_db_file,
    );
    return { %defaults, %{ $self->read_config } };
};

sub _build_db_file {
    my $dir = path(
          $^O eq "MSWin32" ? $ENV{APPDATA}
        : $^O eq 'darwin'  ? '~/Library/Application Support'
        :                    '~/.local/share/'
    )->child('sticker');
    $dir->mkpath if !$dir->exists;
    return $dir->child('bookmarks.db')->stringify;
}

sub startup {
    my $self = shift;
    $self->sql->migrations->from_data->migrate;
    return $self;
}

sub read_config {
    my $self = shift;
    my $file = path( $self->config_file );
    return {} if !$file->exists;
    my $config = Config::Tiny->read( $file, 'utf8' );
    warn Config::Tiny->errstr . "\n" if !$config;
    return {} if !( $config && exists $config->{_} );
    return $config->{_};
}

sub db { return shift->sql->db }

sub import_url {
    my ( $self, $tx, $url ) = @_;
    if ( my $res = $tx->success ) {
        my ( $title, $content );
        if ( $res->headers->content_type =~ 'text/html' ) {
            my $dom = $res->dom;
            $title = $dom->at('title');
            if ($title) {
                $title = b( $title->all_text() )->squish;
            }
            $dom->find('head')->map('remove');
            $dom->find('script')->map('remove');
            my %stopword =
              map { $_ => 1 } @{ $self->stopwords };

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

        my @values = ( $title // '', $content // '', $url, scalar time() );
        $self->db->query( '
		insert or ignore into urls ( title, content, url, add_date )
		VALUES ( ?, ?, ?, ? )', @values );

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
    return;
}

sub import_html {
    my ( $self, @files ) = @_;
    my @attrs;
    for my $file (@files) {
        my $content = path($file)->slurp_utf8;
        my $dom     = Mojo::DOM->new($content);
        my $attrs   = $dom->find('a["href"]')->map('attr')
          ->grep( sub { $_->{href} =~ /^http/ } )->to_array;
        push @attrs, @$attrs;
    }
    my %attrs = map { $self->normalize_url( $_->{href} ) => $_ } @attrs;
    my @urls = keys %attrs;

    @urls = $self->filter_new_urls(@urls);
    return 0 if !@urls;

    $self->ua->on(
        process_url => sub {
            my ( $ua, $tx, $url ) = @_;
            $self->import_url( $tx, $url );
            return if !exists $attrs{$url}->{add_date};
            $self->db->query( 'UPDATE urls SET add_date = ? WHERE url = ?',
                $attrs{$url}->{add_date}, $url );
        }
    );

    $self->ua->add_urls(@urls);
    return;
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

sub filter_new_urls {
    my ( $self, @urls ) = @_;
    $self->db->query(
        'create temp table if not exists tmp_urls (url);delete from tmp_urls;');

    my $tx = $self->db->begin;
    $self->db->query( 'insert into tmp_urls values (?)', $_ ) for @urls;
    $tx->commit;

    return $self->db->query(
        'select url from tmp_urls except select url from urls ')
      ->arrays->flatten->each;
}

1;

__DATA__

@@ migrations

-- 1 up

create table if not exists urls (
	url_id integer primary key,
	title text,
	content text,
	url text unique,
	add_date text
);

-- 2 up

create table if not exists tags (
	tag_id integer primary key,
	name text unique
);

create table if not exists tags_urls (
	tag_id integer references tags,
	url_id integer references urls,
	primary key ( tag_id, url_id )
);

-- 3 up

create table if not exists sources (
	source_id integer primary key,
	location text,
	last_checked integer
);
