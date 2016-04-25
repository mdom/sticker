package App::Sticker::Commands::search;
use Mojo::Base 'App::Sticker::Command';
use Mojo::ByteStream 'b';
use Mojo::Util 'tablify';

has 'queries';

sub run {
    my $self = shift;

    my $stmt = <<'EOF';
        select urls.url_id as id,
               substr(urls.title,0,40) as title,
               urls.url as url
            from urls
                 left outer join tags_urls using (url_id)
                 left outer join tags using (tag_id)
EOF

    my @values;
    my @wheres;
    for my $query ( @{ $self->queries || ['%'] } ) {
        if ( $query =~ /^t:(.*)$/ ) {
            push @values, $1;
            push @wheres, ' tags.name = ? ';
        }
        else {
            $query = "%$query%" if $query ne '%';
            push @values, $query, $query;
            push @wheres, ' ( urls.url like ? or urls.title like ? )';
        }
    }

    $stmt .= 'where ' . join( ' and ', @wheres );

    my $matches = $self->db->query( $stmt, @values )->arrays->to_array;

    my $table = tablify $matches;
    print b($table)->encode;
    return 0;
}

1;
