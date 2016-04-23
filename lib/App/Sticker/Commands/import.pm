package App::Sticker::Commands::import;
use Mojo::Base 'App::Sticker::Command';
use Path::Tiny;

has 'files';

sub run {
    my $self = shift;
    my @attrs;
    for my $file ( @{ $self->files } ) {
        my $content = path($file)->slurp_utf8;
        my $dom     = Mojo::DOM->new($content);
        my $attrs   = $dom->find('a["href"]')->map('attr')
          ->grep( sub { $_->{href} =~ /^http/ } )->to_array;
        push @attrs, @$attrs;
    }
    my %attrs = map { $self->normalize_url( $_->{href} ) => $_ } @attrs;
    my @urls = keys %attrs;

    $self->ua->on(
        process_url => sub {
            my ( $ua, $tx, $url ) = @_;
            $self->import_url( $tx, $url );
            next unless exists $attrs{$url}->{add_date};
            $self->db->query(
                'UPDATE urls SET add_date = ? WHERE url = ?',
                $attrs{$url}->{add_date}, $url
            );
        }
    );

    $self->ua->queue( \@urls );

    $self->ua->start->wait;

    return 0;
}

1;
