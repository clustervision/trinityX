#!/usr/bin/perl -w

# Emulate Gold's 'mybalance' script for SLURM
# 
# Assumes Enforced Limits, with GrpCPUMins set on Accounts (not users)
# 
# Specifically, the following must be set in slurm.conf:
#     AccountingStorageEnforce=limits or AccountingStorageEnforce=safe
# 
# Note there is no longer a requirement to disable half-life decay, as in
# previous versions.
# 
# Requires 'sacctmgr' and 'sreport', and requires a SlurmDBD.
#
# The default reports scrape the usage data from local *_usage files (via
# sshare); these will report the usage (which may have been Decayed or
# Reset) and the available Balance (if there is a Limit set on the account).
#
# The tool can also give a report of historical usage from the SlurmDBD (via
# sreport); no limits or balance are reported in this case, just usage.
# 

# TODO:
# - re-write using SLURM-Perl API


use strict;
use Getopt::Std;
use POSIX qw(strftime);


my %acc_limits = ();
my %acc_usage = ();
my %user_usage = ();
my %user_usage_per_acc = ();
my @my_accs = ();
my $thisuser = (getpwuid($<))[0];	# who is running the script
my $showallusers = 1;
my $showallaccs = 0;
my $show_unformatted_balance = 0;
my $clustername = "";
my $accountname = "";
my ($account, $user, $prev_acc);
my $sreport_start = "";
my $sreport_end   = "";
my $SREPORT_START_OFFSET = 94608000;	# 3 * 365 days, in seconds
my $SREPORT_END_OFFSET   = 172800;	# 2 days to avoid DST issues, in seconds


#####################################################################
# subroutines
#####################################################################
sub usage() {
	print "Usage:\n";
	print "$0 [-h] [-c clustername] [-b accountname] [-a accountname] [-A] [-u username] [-U] [-s yyyy-mm-dd]\n";
	print "\t-h:\tshow this help message\n";
	print "\t-c:\treport on cluster 'clustername' (defaults to the local cluster)\n";
	print "\t-b:\treport unformatted balance of account 'accountname'\n";
	print "\t-a:\treport balance of account 'accountname' (defaults to all accounts of the current user)\n";
	print "\t-A:\treport all accounts (defaults to all accounts of the current user)\n";
	print "\t-U:\treport only the current user's balances (defaults to all users in all accounts of the current user)\n";
	print "\t-u:\treport information for the given username, instead of the current user\n";
	die   "\t-s:\treport historical user/account usage from the DBD via 'sreport', starting from yyyy-mm-dd\n";
}

# format minutes as hours, with thousands comma separator
sub fmt_mins_as_hrs( $ ) {
	my $n = shift;

	if ($n == 0) { return 0; } # nothing to do for 0 hours

	return thous(sprintf("%.0f", $n/60));
}

# add commas
sub thous( $ ) {
	my $n = shift;
	1 while ($n =~ s/^(-?\d+)(\d{3})/$1,$2/);
	return $n;
}

# print headers for the output
sub print_headers( $ ) {
	my $use_sreport = shift;

	if ($use_sreport) {
		printf "%s\n", "-"x70;
		printf "User/Account Utilisation on $clustername $sreport_start - $sreport_end\n";
		printf "Time reported in CPU Hours\n";
		printf "%s\n", "-"x70;
		printf "%-10s %9s | %14s %9s\n",
			"User", "Usage", "Account", "Usage";
		printf "%10s %9s + %14s %9s\n",
			"-"x10, "-"x9, "-"x14, "-"x9;
	} else {
		printf "%-10s %9s | %14s %9s | %13s %9s (CPU hrs)\n",
			"User", "Usage", "Account", "Usage", "Account Limit", "Available";
		printf "%10s %9s + %14s %9s + %13s %9s\n",
			"-"x10, "-"x9, "-"x14, "-"x9, "-"x13, "-"x9;
	}
}

# print the formatted values
sub print_values( $$$$$$ ) {
	my $thisuser = shift;
	my $user_usage = shift;
	my $acc = shift;
	my $acc_usage = shift;
	my $acc_limit = shift;
	my $use_sreport = shift;

	if ($use_sreport) {
		printf "%-10s %9s | %14s %9s\n",
			$thisuser, fmt_mins_as_hrs($user_usage),
			$acc, fmt_mins_as_hrs($acc_usage);
	} else {
		printf "%-10s %9s | %14s %9s | %13s %9s\n",
			$thisuser, fmt_mins_as_hrs($user_usage),
			$acc, fmt_mins_as_hrs($acc_usage),
			fmt_mins_as_hrs($acc_limit),
			($acc_limit == 0) ? "N/A" : fmt_mins_as_hrs($acc_limit - $acc_usage);
	}
}

# print the formatted values
sub print_results( $$$$ ) {
	my $multiple_users = shift;
	my $multiple_accs  = shift;
	my $include_root   = shift;
	my $use_sreport    = shift;

	my @account_list = sort keys %user_usage_per_acc;
	my $first_iter   = 1;
	my $rawusage;

	if ($include_root) {
		# instead of a purely sorted list, show the 'ROOT' account first (assuming
		# that the account is actually called 'ROOT')
		my $root_acc = 'ROOT';

		# linear search (even though the list is sorted and we could do a binary)
		my $index = 0;
		$index++ until ($index > $#account_list || $account_list[$index] eq $root_acc);

		# remove that index from the array
		splice(@account_list, $index, 1);

		# and push 'ROOT' back as the first element
		unshift(@account_list, $root_acc);
	}

	print_headers($use_sreport);
	#printf "\n";

	# now print the values, including those users with no usage
	foreach my $account (@account_list) {

		if (!$first_iter && $multiple_accs) {
			# separate each account
			print "\n";
		}
		$first_iter = 0;

		if (!$multiple_users) {
			# only reporting for a single user

			## stop warnings if this account doesn't have a limit
			#if (! exists($acc_limits{$account})) {
			#	$acc_limits{$account} = 0;
			#}

			# stop warnings if this account doesn't have any usage
			if (! exists($acc_usage{$account})) {
				$acc_usage{$account} = 0;
			}

			#print_values($thisuser, $user_usage{$account}, $account, $acc_usage{$account}, $acc_limits{$account});
			print_values($thisuser, $user_usage_per_acc{$account}{$thisuser}, $account, $acc_usage{$account}, $acc_limits{$account}, $use_sreport);

		} else {
			# else loop over the users

			foreach my $user (sort keys %{ $user_usage_per_acc{$account} } ) {
				# then each subsequent line is an individual user
				# (already in alphabetical order)

				$rawusage = $user_usage_per_acc{$account}{$user};

				# highlight current user
				if ($multiple_users && $user eq $thisuser) {
					$user = "$user *";
				}

				## stop warnings if this account doesn't have a limit
				#if (! exists($acc_limits{$account})) {
				#	$acc_limits{$account} = 0;
				#}

				# stop warnings if this account doesn't have any usage
				if (! exists($acc_usage{$account})) {
					$acc_usage{$account} = 0;
				}

				print_values($user, sprintf("%.0f", $rawusage), $account, $acc_usage{$account}, $acc_limits{$account}, $use_sreport);
			}
		}
	}
}

# query sacctmgr to find the list of users and accounts
# populates the global %user_usage_per_acc HashOfHash
# if $populate_my_accs is not empty, also populate global @my_accs list
sub query_users_and_accounts( $$$ ) {
	my $account_param    = shift;
	my $user_param       = shift;
	my $populate_my_accs = shift;

	my $cluster_str = ($clustername ne "") ? "clusters=$clustername " : "";
	my $query_str = "sacctmgr list accounts withassoc -np $cluster_str format=Account,User ";

	if ($account_param) {
		$query_str .= "accounts=$account_param ";
	} elsif ($user_param) {
		$query_str .= "users=$user_param ";
	}

	# open the pipe and run the query
	open (SACCTMGR, "$query_str |") or die "$0: Unable to run sacctmgr: $!\n";

	while (<SACCTMGR>) {
		# only show outputs for accounts we're part of
		if (/^\s*([^|]+)\|([^|]+)\|/) {
			my $account   = "\U$1"; # normalise account names to uppercase
			my $user      = "$2";

			# put in a zero usage explicitly if the user hasn't run at all
			$user_usage_per_acc{$account}{$user} = 0;

		}
	}

	close(SACCTMGR);

	if ($populate_my_accs) {
		# but only look at my accounts, not all accounts
		foreach my $account (sort keys %user_usage_per_acc) {
			if (exists ($user_usage_per_acc{$account}{$thisuser}) ) {
				push (@my_accs, $account);
			} else {
				# remove the account
				delete $user_usage_per_acc{$account};
			}
		}
	}
}

# query sreport to find the actual usage, for users and/or accounts
# populates the global %user_usage_per_acc HashOfHash
sub query_sreport_user_and_account_usage( $$$ ) {
	my $account_param    = shift;
	my $balance_only     = shift;
	my $thisuser_only    = shift;

	my $rawusage;

	my $cluster_str = ($clustername ne "") ? "clusters=$clustername " : "";
	my $query_str = "sreport -t minutes -np cluster AccountUtilizationByUser start=$sreport_start end=$sreport_end $cluster_str account=$account_param ";

	if ($account_param eq "") {
		die "$0: Unable to run sreport as the account list is empty (the user/account doesn't exist on the cluster perhaps)\n";
	}

	# open the pipe and run the query
	open (SREPORT, "$query_str |") or die "$0: Unable to run sreport: $!\n";

	while (<SREPORT>) {
		# only show outputs for accounts we're part of
		if (/^\s*[^|]+\|([^|]*)\|([^|]*)\|[^|]*\|([^|]*)/) {
			$account      = "\U$1"; # normalise account names to uppercase
			$user         = $2;
			$rawusage     = $3;

			if (exists( $acc_limits{$account} ) && $user eq "") {
				# the first line is the overall account usage
				$acc_usage{$account} = $rawusage;

				# if we only want the unformatted balance, then we're done
				if ($balance_only) {
					last;
				}

			} elsif ($thisuser_only && $user eq $thisuser && exists( $acc_limits{$account} )) {
				# only reporting on the given user, not on all users in the account
				$user_usage_per_acc{$account}{$thisuser} = $rawusage;

			} elsif (exists( $acc_limits{$account} )) {
				# otherwise report on all users in the account
				$user_usage_per_acc{$account}{$user} = $rawusage;

			}
		}
	}

	close(SREPORT);
}

# query sshare to find the actual usage, for users and/or accounts
# populates the global %user_usage_per_acc HashOfHash
sub query_sshare_user_and_account_usage( $$$ ) {
	my $account_param    = shift;
	my $balance_only     = shift;
	my $thisuser_only    = shift;

	my $rawusage;

	my $cluster_str = ($clustername ne "") ? "-M $clustername " : "";
	my $user_str  = ($thisuser_only ne "") ? "" : "-a ";

	my $query_str = "sshare -hp $cluster_str $user_str -A $account_param ";

	if ($account_param eq "") {
		die "$0: Unable to run sshare as the account list is empty (the user/account doesn't exist on the cluster perhaps)\n";
	}

	# open the pipe and run the query
	open (SSHARE, "$query_str |") or die "$0: Unable to run sshare $!\n";

	while (<SSHARE>) {
		# only show outputs for accounts we're part of
		if (/^\s*([^|]+)\|([^|]*)\|[^|]*\|[^|]*\|([^|]*)/) {
			$account      = "\U$1"; # normalise account names to uppercase
			$user         = $2;
			$rawusage     = $3;

			if (exists( $acc_limits{$account} ) && $user eq "") {
				# the first line is the overall account usage
				$acc_usage{$account} = sprintf("%.0f", $rawusage/60); # sshare reports in seconds

				# if we only want the unformatted balance, then we're done
				if ($balance_only) {
					last;
				}

			} elsif ($thisuser_only && $user eq $thisuser && exists( $acc_limits{$account} )) {
				# only reporting on the given user, not on all users in the account
				$user_usage_per_acc{$account}{$thisuser} = sprintf("%.0f", $rawusage/60); # sshare reports in seconds

			} elsif (exists( $acc_limits{$account} )) {
				# otherwise report on all users in the account
				$user_usage_per_acc{$account}{$user} = sprintf("%.0f", $rawusage/60); # sshare reports in seconds

			}
		}
	}

	close(SSHARE);
}


#####################################################################
# get options
#####################################################################
my %opts;
getopts('hc:b:a:Au:Us:', \%opts) || usage();

if (defined($opts{h})) {
	usage();
}

if (defined($opts{c})) {
	$clustername = $opts{c};
}

if (defined($opts{b})) {
	$show_unformatted_balance = 1;
	$showallusers = 0;
	$accountname = "\U$opts{b}"; # normalise account names to uppercase
}

if (defined($opts{a})) {
	$accountname = "\U$opts{a}"; # normalise account names to uppercase
}

if (defined($opts{A})) {
	$showallaccs = 1;
}

if (defined($opts{u})) {
	$thisuser = $opts{u};
}

if (defined($opts{U})) {
	$showallusers = 0;
}

if (defined($opts{s})) {
	unless ($opts{s} =~ /^\d{4}-\d{2}-\d{2}$/) { usage(); }

	if (defined($opts{b})) {
		die "$0: the 'sreport' parameter doesn't make sense for the unformatted balance query. Exiting..\n";
	}

	$sreport_start = $opts{s};
	$sreport_end   = strftime "%Y-%m-%d", (localtime(time() + $SREPORT_END_OFFSET));
#} else {
#	$sreport_start = strftime "%Y-%m-%d", (localtime(time() - $SREPORT_START_OFFSET));
#	$sreport_end   = strftime "%Y-%m-%d", (localtime(time() + $SREPORT_END_OFFSET));
}


#####################################################################
# start
# get the local clustername, or use the given clustername
#####################################################################

if ($clustername eq "") {
	open (SCONTROL, 'scontrol show config |')
		or die "$0: Unable to run scontrol: $!\n";

	while (<SCONTROL>) {
		if (/^ClusterName\s*=\s*(\S+)/) {
			$clustername = $1;
		}
	}

	close(SCONTROL);

	if ($clustername eq "") {
		die "$0: Unable to determine local cluster name via scontrol. Exiting..\n";
	}
}


#####################################################################
# run sacctmgr to find all Account limits from the list of 
# Assocations
# note that gives us the current active Accounts, which is useful
# because sreport will show usage from deleted accounts
#####################################################################

open (SACCTMGR, "sacctmgr list association cluster=$clustername format='Account,GrpCPUMins'" .
		" -p -n |")
	or die "$0: Unable to run sacctmgr: $!\n";

# GrpCPUMins are not in 'sreport'
while (<SACCTMGR>) {
	# format is "acct_string|nnnn|" where nnnn is the number of GrpCPUMins allocated
	if (/^([^|]+)\|([^|]*)/) {
		if ($2 ne "") {
			$acc_limits{"\U$1"} = sprintf("%.0f", $2); # normalise account names to uppercase
		} elsif (!exists($acc_limits{"\U$1"})) {
			# store all accounts, even those without GrpCPUMins allocated, so we can report usage
			$acc_limits{"\U$1"} = 0; # normalise account names to uppercase
		}
	}

}

close(SACCTMGR);


######################################################################
## quick sanity check - did we find any GrpCPUMins ?
## removing this check, as we are now storing all accounts in %acc_limits
######################################################################
#
#if ((scalar keys %acc_limits) == 0) {
#	warn "$0: warning: unable to find any GrpCPUMins set on Accounts in cluster '$clustername' via sacctmgr. Only Usage will be reported, not available balance.\n";
#}


#########################################################################################
# main code: there are a few different combinations:
# - Scenario #1 showallusers in a named account
# - Scenario #2 showallusers in every account, not just mine
# - Scenario #3 showallusers in all of my accounts
# - Scenario #4 show unformatted balance as a single figure, for the named account
# - Scenario #5 show only my usage, in all of my accounts
#########################################################################################


if ($showallusers && $accountname ne "") {
	#####################################################################
	# - Scenario #1 showallusers in a named account
	# only look to a specified account, rather than all
	# show all users in the given account
	#####################################################################

	my $cluster_str = ($clustername ne "") ? "clusters=$clustername " : "";

	if (!exists($acc_limits{$accountname})) {
		die "$0: account '$accountname' doesn't exist. Exiting..\n";
	}

	# first obtain the full list of users for this account; sreport won't report
	# on them if they have no usage
	query_users_and_accounts($accountname, "", "");

	if (defined($opts{s})) {
		# SREPORT: get the usage values (for all users in the accounts), for just the named account
		query_sreport_user_and_account_usage($accountname, "", "");
	} else {
		# SSHARE get the usage values (for all users in the accounts), for just the named account
		query_sshare_user_and_account_usage($accountname, "", "");
	}

	# display formatted output
	print_results(1, 0, 0, defined($opts{s}));

} elsif ($showallusers && $showallaccs) {
	#####################################################################
	# - Scenario #2 showallusers in every account, not just mine
	# we need to show all users in ALL Accounts
	#####################################################################

	my $cluster_str = ($clustername ne "") ? "clusters=$clustername " : "";

	# first obtain the full list of users for all accounts; sreport won't report
	# on them if they have no usage
	query_users_and_accounts("", "", "");

	if (defined($opts{s})) {
		# SREPORT: get the usage values (for all users in the accounts), for all accounts (all the ones found by sacctmgr above)
		query_sreport_user_and_account_usage(join(',', sort(keys (%acc_limits))), "", "");
	} else {
		# SSHARE: get the usage values (for all users in the accounts), for all accounts (all the ones found by sacctmgr above)
		query_sshare_user_and_account_usage(join(',', sort(keys (%acc_limits))), "", "");
	}

	# display formatted output
	print_results(1, 1, 1, defined($opts{s}));

} elsif ($showallusers) {
	#####################################################################
	# - Scenario #3 showallusers in all of my accounts
	# if we need to show all users in all our Accounts, then we have to
	# run sacctmgr first, then sreport - first to find all Accounts that I'm a part of,
	# and secondly to dump all users in those accounts
	#####################################################################

	my $cluster_str = ($clustername ne "") ? "clusters=$clustername " : "";

	###############################################################################
	# sacctmgr #1 -- obtain the usage for this user, and also the list of all of their accounts
	###############################################################################

	# first obtain the full list of users for all accounts; sreport won't report
	# on them if they have no usage
	query_users_and_accounts("", "", 1);

	if (defined($opts{s})) {
		# SREPORT: get the usage values (for all users in the accounts), for all the accounts of the given user
		query_sreport_user_and_account_usage(join(',', sort(@my_accs)), "", "");
	} else {
		# SSHARE get the usage values (for all users in the accounts), for all the accounts of the given user
		query_sshare_user_and_account_usage(join(',', sort(@my_accs)), "", "");
	}

	# display formatted output
	print_results(1, 1, 0, defined($opts{s}));

} elsif ($show_unformatted_balance && $accountname ne "") {
	#####################################################################
	# - Scenario #4 show unformatted balance as a single figure, for the named account
	# show only the balance for $accountname, unformatted
	#####################################################################

	#my $cluster_str = ($clustername ne "") ? "-M $clustername " : "";
	my $cluster_str = ($clustername ne "") ? "clusters=$clustername " : "";

	if (!exists($acc_limits{$accountname})) {
		die "$0: account '$accountname' doesn't exist. Exiting..\n";
	}

	# SSHARE: get the usage value, for all single given account
	query_sshare_user_and_account_usage($accountname, 1, "");

	if ($acc_usage{$accountname} eq "") {
		die "$0: invalid account string '$accountname'\n";
	}

	# this is minutes - we need to convert to hours
	printf "%.0f\n", (($acc_limits{$accountname} - $acc_usage{$accountname})/60);

} else {
	#####################################################################
	# - Scenario #5 show only my usage, in all of my accounts
	# only show my usage in the Accounts
	# run sacctmgr first, then sreport - first to find all Accounts that I'm a part of,
	# and secondly to dump all users in those accounts
	#####################################################################

	my $cluster_str = ($clustername ne "") ? "clusters=$clustername " : "";

	###############################################################################
	# sacctmgr #1 -- obtain the usage for this user, and also the list of all of their accounts
	###############################################################################

	query_users_and_accounts("", $thisuser, 1);

	if (defined($opts{s})) {
		# SREPORT get the usage values (for just the given user), for all the accounts of the given user
		query_sreport_user_and_account_usage(join(',', sort(@my_accs)), "", 1);
	} else {
		# SSHARE: get the usage values (for just the given user), for all the accounts of the given user
		query_sshare_user_and_account_usage(join(',', sort(@my_accs)), "", 1);
	}

	# display formatted output
	print_results(0, 0, 0, defined($opts{s}));

}

