package App::Sticker::Commands::search;
use Mojo::Base 'App::Sticker::Command';
use Mojo::ByteStream 'b';
use Mojo::Util 'tablify';

has 'query';

sub run {
    my $self = shift;
    my $query = $self->query ? '%' . $self->query . '%' : '%';

    my @matches =
      $self->db->query( 'select rowid,substr(title,0,40),url from urls where url like ? or title like ?',
        $query, $query )->arrays->each;

    my $table = tablify [ [qw(ID TITLE URL)], @matches ];
    print b($table)->encode;
    return 0;
}

1;
