package App::Sticker::Commands::add;
use Mojo::Base 'App::Sticker::Command';

has 'urls';

sub run {
    my $self = shift;
    my @urls = map { $self->normalize_url($_) } @{ $self->urls };
    @urls = $self->filter_new_urls(@urls);
    return 0 if !@urls;

    $self->ua->queue( \@urls );
    $self->ua->on(
        process_url => sub {
            my ( $ua, $tx, $url ) = @_;
            $self->import_url( $tx, $url );
        }
    );
    $self->ua->start->wait;
    return 0;
}

1;

__END__

=pod

=head1 Foo

bar
