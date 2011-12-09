#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use lib '/home/rob/dev/bioperl/Bio-FeatureIO/lib';
use Bio::SeqIO;
use Bio::FeatureIO;

my $cdna_seqs = Bio::SeqIO->new( -file => shift, -format => 'fasta' );
my $features_in  = Bio::FeatureIO->new( -file => shift, -format => 'gff', -version => 3 );
my $features_out = Bio::FeatureIO->new( -fh => \*STDOUT, -format => 'gff', -version => 3 );

my $trims = find_trim_regions( $cdna_seqs );

while( my @f = $features_in->next_feature_group ) {
    for my $feature ( @f ) {
        my ( $name ) = eval { $feature->get_tag_values('Name') };
        if( my $trim = $name && $trims->{$name} ) {
            trim_feature( $feature, $trim );
        }
        $features_out->write_feature( $feature );
    }
}

############## subs ###############

sub trim_feature {
    my ( $feature, $trim ) = @_;

    my ( $name ) = eval { $feature->get_tag_values('Name') } or return;

    $feature->primary_tag eq 'gene'
        or die "don't know how to handle ".$feature->primary_tag." feature $name";

    my ( $start, $end ) = $feature->start, $feature->end;

    my ( $trim_start, $trim_end ) = ( $trim->{"5'"}, $trim->{"3'"} );
    ( $trim_start, $trim_end ) = ( $trim_end, $trim_start ) if $feature->strand == -1;

    $start += $trim_start if $trim_start;
    $end   -= $trim_end   if $trim_end;

    recursive_trim_to_bounds( $feature, $start, $end );
}

sub recursive_trim_to_bounds {
    my ( $feature, $start, $end ) = @_;

    recursive_trim_to_bounds( $_, $start, $end ) for $feature->get_SeqFeatures;

    $feature->start( $start ) if $start && $feature->start < $start;
    $feature->end( $end )     if $end   && $feature->end   < $end;
}

sub find_trim_regions {
    my ( $cdna_seqs ) = @_;
    my %trims;
    while ( my $cdna = $cdna_seqs->next_seq ) {
        my $seq = $cdna->seq;
        ( my $gene_id = $cdna->id ) =~ s/\.\d+$//;
        # leading Ns
        if ( $seq =~ /^(N+)/i ) {
            $trims{$gene_id}{"5'"} = length $1;
        }

        # trailing Ns
        if ( $seq =~ /(N+)$/i ) {
            $trims{$gene_id}{"3'"} = length $1;
        }
    }

    return \%trims;
}
