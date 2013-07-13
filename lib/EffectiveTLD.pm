
# vim: ft=perl

package EffectiveTLD;

use lib '~/perl5';
use common::sense;
use AnyEvent;
use AnyEvent::HTTP;
use JSON::XS;

use constant {
    DEBUG       => 1,
    ATOM_LOG    => 'http://hg.mozilla.org/mozilla-central/atom-log/tip/netwerk/dns/effective_tld_names.dat',
    TIP_FILE    => 'http://mxr.mozilla.org/mozilla-central/source/netwerk/dns/effective_tld_names.dat?raw=1',
};

my $DIR_WORK    = '/tmp/effective_tld/tmp';
my $DIR_STOR    = '/tmp/effective_tld/stor';
my $JSON_FLAT   = '/tmp/effective_tld/stor/tld_flat.json';
my $JSON_REV    = '/tmp/effective_tld/stor/tld_rev.json';
my $JSON_TREE   = '/tmp/effective_tld/stor/tld_tree.json';
my $JSON_LOG    = '/tmp/effective_tld/stor/changes.json';


sub fetchRaw {
    my $cv  = shift || AE::cv;
    $cv->begin;
    return AnyEvent::HTTP::http_get(
        TIP_FILE(),
        sub {
            my($raw,$hdr) = @_;
            parseRaw($raw);
            $cv->end;
        }
    );
}

sub fetchAtom {
    my $cv  = shift || AE::cv;
    $cv->begin;
    return AnyEvent::HTTP::http_get(
        ATOM_LOG,
        sub {
            my($raw,$hdr) = @_;
            parseAtom($raw);
            $cv->end;
        }
    );
}


sub parseAtom {
    my $raw = shift
        or return;
    my $res;
    $raw =~ s{
        (<entry>([\s\S]*?)</entry>)
    }{
        my $r =parseEntry($1);
        push @$res, $r if $r && $r->{id};
    }xeg;
    store($JSON_LOG,$res)
        or warn "failed to store - check it";
};


sub parseEntry {
    my $raw = shift 
        or return;
    $raw   =~m@<entry>([\s\S]*?)</entry>@i  
        or return;
    my $e   = $1;
    my $r; 
    $r->{$_} = $e =~ m@<$_>(.*?)</$_>@i ? $1 : undef
        for qw( id name updated published title );
    $r->{link}  = $e =~ m@<link href="(.*?)"@i ? $1 : undef;
    $r->{msg}   = $e =~ m@<pre.*?>(.*?)</pre@i ? $1 : undef;
    $r;
}


sub parseRaw {
    my $raw     = shift
        or return;
    my (%flat,%rev);
    my $tree = {};
    foreach (split(/\n/, $raw)){
        ( m@^//@ or m@^\s*$@ ) 
            and next;
        m@(\S+)@ or next;
        my $tld = $1;
        $flat{$tld}++;
        $rev{ join('.', reverse split(/\./, $tld))}++;
        # create a tree with depth
        my $p = {};
        my $n = 0;
        map {
            my $e = $n == 0 ? $tree : $p->{sub};
            $e->{$_}->{depth} = $n;
            $e->{$_}->{ct}++;
            $e->{$_}->{sub} ||= {};
            $p = $e->{$_};
            $n++;
        } reverse split(/\./, $tld);
        delete $p->{sub};           # truncate the last one's -should not be populated
    }
    store($JSON_FLAT,\%flat);
    store($JSON_REV,\%rev);

    # create a depth metric
    my (%d, $count_depth); $count_depth = sub { 
        my ($k,$r)  = @_;
        $d{$k}++;
        return ( $r && $r->{sub} ) ? $count_depth->($k,$r->{sub}) : $d{$k};
    };
    $tree->{$_}->{max_depth} = $count_depth->($_, $tree->{$_} )
        for keys %$tree;

    store($JSON_TREE,$tree);
}

sub store {
    my ($f,$data) = @_;
    my $fh;
    DEBUG   and warn "saving $f\n";
    if( ref $data and open( $fh, '>', $f) ){
        print $fh JSON::XS->new->pretty->canonical->encode($data); 
        close $fh;
        return 1;
    } else{
        warn "$f -- Not saved! empty or error($!)\n";
        return 0;
    }
}




sub main{
    my $o       = shift ||  {};

    -d $DIR_WORK or print STDERR "mkdir ", $DIR_WORK, qx{ mkdir -p $DIR_WORK }, "\n";
    -d $DIR_STOR or print STDERR "mkdir ", $DIR_STOR , qx{ mkdir -p $DIR_STOR }, "\n";

    my %g;
    my $cv      = AE::cv;

    $g{raw}     = fetchRaw($cv);
    $g{rss}     = fetchAtom($cv);

    $cv->wait;
}



main();

1;

__END__

