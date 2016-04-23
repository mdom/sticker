package App::Sticker::Commands::search;
use Mojo::Base 'App::Sticker::Command';
use Mojo::ByteStream 'b';
use Mojo::Util 'tablify';

has 'queries';

sub run {
    my $self = shift;

    my $stmt =  'select url_id,substr(title,0,40),url from urls ';

    my @values;
    my @wheres;
    for my $query ( @{ $self->queries || [ '%' ] } ) {
	    $query = "%$query%" if $query ne '%';
	    push @values, $query, $query;
	    push @wheres, ' ( url like ? or title like ? )';
    }

    $stmt .= 'where ' . join(' and ', @wheres);

    my $matches =
      $self->db->query( $stmt, @values )->arrays->to_array;

    my $table = tablify $matches;
    print b($table)->encode;
    return 0;
}

1;
