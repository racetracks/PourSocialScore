FLAVOURS=${PSS_FLAVOURS:-retail forever tbc}
FLAVOUR_ENVS=""
for f in $FLAVOURS; do FLAVOUR_ENVS="$FLAVOUR_ENVS PSS_FLAVOUR=$f"; done
# save_key <built save>: sk_c client, sk_v version, sk_s save (main when the
# out dir is the old <client>/<version>/ layout), sk_id <version>[-<save>]
save_key() {
	sk_s=$(basename "$(dirname "$1")"); sk_v=$(basename "$(dirname "$(dirname "$1")")")
	sk_c=$(basename "$(dirname "$(dirname "$(dirname "$1")")")")
	case " retail forever tbc era mists " in *" $sk_v "*) sk_c=$sk_v; sk_v=$sk_s; sk_s=main ;; esac
	sk_id=$sk_v; [ "$sk_s" = main ] || sk_id="$sk_v-$sk_s"
}
