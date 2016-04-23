package App::Sticker::Commands::open;
use Mojo::Base 'App::Sticker::Command';
use String::ShellQuote 'shell_quote';

has 'id';

sub run {
    my $self = shift;
    my $url =
      $self->db->query( 'select url from urls where url_id = ?', $self->id )->hash->{url};
    return 1 if !$url;
    my $viewer = $self->config->{url_viewer};
    my $command = sprintf( $viewer, shell_quote($url) );
    system($command) == 0
      or warn "Error calling $command: $!\n";
    return 0;
}

1;
