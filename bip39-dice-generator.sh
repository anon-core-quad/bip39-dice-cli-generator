#!/bin/bash

export BC_LINE_LENGTH=0
DEBUG=0

ENTROPY=256 #bits
CHECKSUM_QUARTRAIN=2
SEED_WORDS=24
CHECKSUM_BITS=8

# Dice faces, default is 6 => D6
# Note: if you have 2 faces, you are probably flipping a coin :)
dice_faces=6

# The full sequence entered from prompt, contain the resuls achieved by the throws of dices or coins
dice_throws_sequence=''

show_help() {
	local bold=$'\033[1m'
    local reset=$'\033[0m'
	local dim=$'\033[2m'
    local cyan=$'\033[36m'
cat <<EOF
Usage: $0 [OPTIONS]

Description:
Generate BIP-39 wallet seed phrases from physical dice rolls - offline, transparent, and privacy-focused.

Options:
${bold}-h${reset}			Show this help message 
${bold}-s${reset}			The numbers rolled on the dice, witout spaces	[required]
${bold}-f${reset}			The number of faces of the dice
			[default: 6]
${bold}-w${reset}			Words to generate: 12 or 24
			If you want to generate 12 words the entropy is setted to 128 bits, 
			for 24 words is setted to 256 bits
			[default: 24]

Examples:
Generate 24 words seed from default D6 dice throws
${dim}$ bash bip39-dice-generator.sh -s 123124465261[...]4135612546${reset}

Generate 24 words seed from coin flipping
${dim}$ bash bip39-dice-generator.sh -s 1212122222[...]122222211 -f 2 -w 24${reset}

Generate 12 words seed from D8
${dim}$ bash bip39-dice-generator.sh -s 123124465261[...]5612546 -f 8 -w 12${reset}			
EOF
}

while getopts "hf:s:w:" opt; do
	case $opt in
		h) show_help && exit 0;;
		f) dice_faces=$(echo $OPTARG);;
		w) 
			if [ $OPTARG -eq "12" ]; then
				ENTROPY=128
				CHECKSUM_QUARTRAIN=1
				CHECKSUM_BITS=4
				SEED_WORDS=12
			fi
		;;
		s) dice_throws_sequence=$(echo $OPTARG | tr -d ' ');;
  	esac
done

GENERATED_WORDS=$(( (SEED_WORDS - 1) * 11 ))

all_in_range() {
    local lo=1 hi=$dice_faces
    shift 2
	returnValue=0

	for ((x=0; x<${#dice_throws_sequence}; x++)); do
		val=${dice_throws_sequence:x:1}
		if (( val < lo || val > hi )); then 
			returnValue=1
			break
		fi
	done

    echo $returnValue
}

checkInsertedNumbers=$(all_in_range)

if [[ ${checkInsertedNumbers} -eq 1 ]]; then 
	echo "ERROR: You must insert number between 1 and $dice_faces"	
	exit 1
fi

if [[ ${SEED_WORDS} -ne 12 && ${SEED_WORDS} -ne 24 ]]; then 
	echo "ERROR: you need to select 12 or 24 words"	
	exit 1
fi

# Convert dice throws sequence in a hash sha256, so it's pointless to get more entropy
sha256value=$(sha256sum <<<$dice_throws_sequence | awk '{print $1}')
if [ $ENTROPY -eq 128 ]; then 
	# Get only the first 32 bytes if entropy is 128 bits
	sha256value=$(echo -n $sha256value | cut -c 1-32)
fi

# Calculate the number of rolls needed, based on how many faces have the dices
base_entropy=$(echo "l($dice_faces)/l(2)" | bc -l)
needed_number_of_rolls=$(bc -l <<< "$ENTROPY / $base_entropy")

# Round result to units
needed_number_of_rolls=$(awk -v rolls="$needed_number_of_rolls" 'BEGIN { printf "%.0f\n", rolls }')

printf "%-20s %-10s\n" "Param" "Value"
echo "----------------------------"
printf "%-20s %-10s\n" "Entropy" "$ENTROPY"
printf "%-20s %-10s\n" "Words" "$SEED_WORDS"
printf "%-20s %-10s\n" "Dice Faces" "$dice_faces"
printf "%-20s %-10s\n" "Needed throws" "$needed_number_of_rolls"
printf "%-20s %-10s\n" "Inserted throws" "${#dice_throws_sequence}"
echo "----------------------------"

echo -e "\nInserted sequence:\n$dice_throws_sequence\n"

if [ $DEBUG -eq 0 ]; then
	if [ ${#dice_throws_sequence} -lt $needed_number_of_rolls ]; then 
		echo "ERROR: you need at least $needed_number_of_rolls values."	
		exit 1
	fi
fi

echo -e "Generated SHA256 from sequence:\n$sha256value \n"

# Lookup table for binary conversion
hex2bin=(0000 0001 0010 0011 0100 0101 0110 0111 1000 1001 1010 1011 1100 1101 1110 1111)

BINARY_CONVERSION=""
for (( i=0; i<${#sha256value}; i++ )); do
	BINARY_CONVERSION+=${hex2bin[$((16#${sha256value:$i:1}))]}
done

if [ $DEBUG -eq 1 ]; then
	echo -e "SHA256 BINARY CONVERSION:\n$(echo -n "$BINARY_CONVERSION" | fold -w 11) \n"
fi

LEFTOVERBITS=$(echo -n $BINARY_CONVERSION | cut -c $((GENERATED_WORDS-ENTROPY)) | awk '{print $1}')

# Convert from HEX (human readable ascii format) to binary data (machine readable) and reconvert in sha256
ENTROPY_BYTES=$(echo -n $sha256value | xxd -r -p | sha256sum | awk '{print $1}')


# Get the fist 8 bits (24 words) or 4 bits (12 words) from the Sha256 of the entropy (in bytes)
CHECKSUM_BYTE=$(echo -n $ENTROPY_BYTES | cut -c 1-$CHECKSUM_QUARTRAIN)

# Convert the byte of checksum in binary digits
CHECKSUM_BINARY=${hex2bin[ $((16#${CHECKSUM_BYTE:0:1})) ]}
if [ $ENTROPY -eq 256 ]; then
	CHECKSUM_BINARY+=${hex2bin[ $((16#${CHECKSUM_BYTE:1:1})) ]}
fi

# Create the last word of the seed (checksum)
LAST_WORD=$LEFTOVERBITS$CHECKSUM_BINARY

if [ $DEBUG -eq 1 ]; then
	echo "CHECKSUM BYTE: $CHECKSUM_BYTE"
	echo "CHECKSUM BINARY: $CHECKSUM_BINARY"
	echo "LEFT OVER BITS: $LEFTOVERBITS" 
	echo "CHECKSUM: $CHECKSUM_BINARY" 
fi

echo "LAST WORD: $LAST_WORD" 

finalMnemonics=$BINARY_CONVERSION$CHECKSUM_BINARY

if [[ $DEBUG -eq 0 && ! -f "bip39-english.txt" ]]; then
	# Download official BIP39 word list
	wget -O bip39-english.txt https://raw.githubusercontent.com/bitcoin/bips/refs/heads/master/bip-0039/english.txt 
	echo -e "\n"
fi

declare -A bip39words
j=1
while IFS= read -r line; do
	bip39words[$j]=$line
	((j++))
done < bip39-english.txt

# Create a tridimensional array with binary values, integer converted values and the corrispondent bip39 word
declare -A finalMatrix
i=1
while IFS= read -r group; do
	decimalConversion=$((2#$group+1))
	finalMatrix["$i,0"]=$group
	finalMatrix["$i,1"]=$decimalConversion
	finalMatrix["$i,2"]=${bip39words[$decimalConversion]}
	finalMatrix["$i,3"]=$i
	((i += 1))
done < <(fold -w11 <<< "$finalMnemonics")


# Print a table of the results
printf "%-8s %-15s %-10s %-20s\n" "Position" "Binary" "Decimal+1" "Word"
printf "%s\n" "---------------------------------------"
for i in $(seq 1 $((SEED_WORDS))); do
    printf "%-8s %-15s %-10s %-20s\n" "${finalMatrix[$i,3]}" "${finalMatrix[$i,0]}" "${finalMatrix[$i,1]}" "${finalMatrix[$i,2]}"
done

echo ""

COLUMNS=100

# Print inline seed words
printf "SEED WORDS:\n"
printf '=%.0s' $(seq 1 $((COLUMNS)))
printf "\n"
for i in $(seq 1 $((SEED_WORDS))); do
    printf "%s " "${finalMatrix[$i,2]}"
done
printf "\n"
printf '=%.0s' $(seq 1 $((COLUMNS)))
printf "\n"