#!/usr/bin/env bash

set -x
set -e

cd $(git rev-parse --show-toplevel)

OUTPUT_DIR="out"

CONTROL_DIR="dts"
CONTROL_DTS_IN="${CONTROL_DIR}/control.dts.in"
CONTROL_DTS="${OUTPUT_DIR}/control.dts"
CONTROL_DTB="${OUTPUT_DIR}/control.dtb"
CONTROL_GEN_PUBKEY="${OUTPUT_DIR}/control-gen-pubkey.dtsi"

KEY_DIR="${OUTPUT_DIR}/keys"
KEY_KEY_FILE="${KEY_DIR}/uboot_sign_key.key"
KEY_CRT_FILE="${KEY_DIR}/uboot_sign_key.crt"

FIT_DIR="fit"
FIT_ITS="${FIT_DIR}/fitImage.its"
FIT_ITB="${OUTPUT_DIR}/fitImage.itb"
FIT_ITB_SIGN="${OUTPUT_DIR}/fitImage.itb.sign"

mkdir -p ${OUTPUT_DIR}
mkdir -p ${FIT_DIR}
mkdir -p ${KEY_DIR}
mkdir -p ${CONTROL_DIR}

# step 1 - generate keys

openssl genrsa -out ${KEY_KEY_FILE} 4096
openssl req -batch -new -x509 -key ${KEY_KEY_FILE} -out ${KEY_CRT_FILE}

# step 2 - generate control-gen-pubkey.dtsi

./tools/ubpubkey.py ${KEY_CRT_FILE} ${CONTROL_GEN_PUBKEY}

# step 3 - insert control-gen-pubkey.dtsi into control.dts

cpp -P -x assembler-with-cpp -I${OUTPUT_DIR} -nostdinc -undef -D__DTS__ ${CONTROL_DTS_IN} -o ${CONTROL_DTS}

# step 4 - compile control.dtb

dtc -I dts ${CONTROL_DTS} -O dtb -o ${CONTROL_DTB}

# step 5 - generate fit image (without signing)

mkimage -f ${FIT_ITS} -r ${FIT_ITB}

# step 6 - sign itb fit container

cp -f ${FIT_ITB} ${FIT_ITB_SIGN}
mkimage -F -k ${KEY_DIR}/ -r ${FIT_ITB_SIGN}

# step 7 - verify

fit_check_sign -f ${FIT_ITB_SIGN} -k ${CONTROL_DTB}
