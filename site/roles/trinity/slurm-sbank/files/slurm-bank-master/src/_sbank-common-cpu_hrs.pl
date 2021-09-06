#!/usr/bin/perl -w

# Display available CPU hours/minutes/seconds per
# interval (year/month/week/day) on a given cluster
# 
# Default to CPU hours/mins/secs per year on all clusters
# 
# Obtain and format the data from SLURM's sinfo


use strict;
use Getopt::Std;
use Switch;

my ($clustername, $partition, $interval, $display_period, $cpu_secs, $result, $n_cores);

sub usage() {
	print "Usage:\n";
	die "$0 [-t {all|hours|minutes|seconds}] [-i {year|month|week|day}] [-p <partition>] [-M all|<clustername>]\n";
}

# add commas
sub thous( $ ) {
	my $n = shift;
	1 while ($n =~ s/^(-?\d+)(\d{3})/$1,$2/);
	return $n;
}


# get options
my %opts;
getopts('ht:p:i:M:', \%opts) || usage();

if (defined($opts{h})) {
	usage();
}

if (defined($opts{t})) {
	$display_period = $opts{t};
} else {
	$display_period = "all";
}

if (defined($opts{i})) {
	$interval = $opts{i};
} else {
	$interval = "year";
}

if (defined($opts{M})) {
	$clustername = $opts{M};
} else {
	$clustername = "all";
}

if (defined($opts{p})) {
	$partition = "-p $opts{p}";
} else {
	$partition = "";
}


# run sinfo
open (SINFO, 'sinfo -o "%C" -h ' . (($clustername ne "") ? "-M $clustername" : "") . " $partition |") or die "Unable to run sinfo: $!\n";

# grab the data
while (<SINFO>) {
	if (/^CLUSTER: (\S+)/) {
		$clustername = $1;
		next;
	}
	next if (/^CPUS/);
	next if (/^$/);

	if (m#^\d+/\d+/\d+/(\d+)#) {
		$n_cores = $1;
	}


	# sinfo not successful?
	if (!$n_cores) {
		die "$0: Unable to read the number of cores";
	}


	# calc the number of seconds
	switch ($interval) {
		case "year"  { $cpu_secs = $n_cores * 60 * 60 * 24 * 365; }
		case "month" { $cpu_secs = $n_cores * 60 * 60 * 24 * 30; }
		case "week"  { $cpu_secs = $n_cores * 60 * 60 * 24 * 7; }
		case "day"   { $cpu_secs = $n_cores * 60 * 60 * 24; }
		else         { usage(); }
	}


	# calc the number of seconds
	switch ($display_period) {
		case "hours"   { $result = sprintf("%16s", thous($cpu_secs/3600) . " hrs"); }
		case "minutes" { $result = sprintf("%20s", thous($cpu_secs/60) . " mins"); }
		case "seconds" { $result = sprintf("%22s", thous($cpu_secs) . " secs"); }
		case "all"     { $result = sprintf("%16s", thous($cpu_secs/3600) . " hrs") . sprintf("%20s", thous($cpu_secs/60) . " mins") . sprintf("%22s", thous($cpu_secs) . " secs"); }
		else           { usage(); }
	}


	# output
	printf "Cluster = %-10s", (($clustername eq "") ? "<local>" : $clustername);
	if ($partition ne "") {
		$partition =~ s/^-p //;
		printf "Partition = %-9s", $partition;
	}
	printf "Cores = %6d  ", $n_cores;
	printf "Period = %-7s", $interval;
	printf "Avail = $result\n";

}

# tidy up
close(SINFO);

