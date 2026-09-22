#!/bin/bash

export BC_LINE_LENGTH=0
DEBUG=0

ENTROPY=256 #bits
CHECKSUM_QUARTRAIN=2
SEED_WORDS=24
LEFT_OVER_BITS_COUNT=2

# Dice faces, default is 6 => D6
# Note: if you have 2 faces, you are probably flipping a coin :)
dice_faces=6

# The full sequence entered from prompt, contain the resuls achieved by the throws of dices or coins
dice_throws_sequence=''

while getopts "hf:s:w:" opt; do
	case $opt in
		h) echo "Usage $0 -s sequence [-f faces] [-e entropy]";;
		f) dice_faces=$(echo $OPTARG);;
		w) 
			SEED_WORDS=$(echo $OPTARG)
			if [ $OPTARG -eq "12" ]; then
				ENTROPY=128				
				CHECKSUM_QUARTRAIN=1
				LEFT_OVER_BITS_COUNT=6
			fi
		;;
		s) dice_throws_sequence=$(echo $OPTARG | tr -d ' ');;
  	esac
done

if [[ ${SEED_WORDS} -ne 12 && ${SEED_WORDS} -ne 24 ]]; then 
	echo "ERROR: you need to select 12 or 24 words"	
	exit 1
fi

# Convert dice throws sequence in a hash sha256, so it's pointless to get more entropy
sha256value=$(sha256sum <<<$dice_throws_sequence | awk '{print $1}')

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

hex2bin=(0000 0001 0010 0011 0100 0101 0110 0111 1000 1001 1010 1011 1100 1101 1110 1111)

bin=""
for (( i=0; i<${#sha256value}; i++ )); do
	bin+=${hex2bin[$((16#${sha256value:$i:1}))]}
done

BINARY_CONVERSION=$(echo -n $bin | cut -c 1-$((ENTROPY)))

if [ $DEBUG -eq 1 ]; then
	echo -e "SHA256 BINARY CONVERSION:\n$(echo "$BINARY_CONVERSION" | fold -w 11) \n"
fi

LEFTOVERBITS=$(echo -n $bin | cut -c $((ENTROPY - LEFT_OVER_BITS_COUNT))-$ENTROPY | awk '{print $1}')

# Convert from HEX (human readable ascii format) to binary data (machine readable) and reconvert in sha256
ENTROPY_BYTES=$(printf '%s' $sha256value | xxd -r -p | sha256sum)

# Get the fist 8 bits (24 words) or 4 bits (12 words) from the Sha256 of the entropy (in bytes)
CHECKSUM_BYTE=$(echo -n $ENTROPY_BYTES | cut -c 1-$CHECKSUM_QUARTRAIN)

for (( i=0; i<${#CHECKSUM_BYTE}; i++ )); do
	CHECKSUM_BINARY+=${hex2bin[$((16#${sha256value:$i:1}))]}
done

LAST_WORD=$LEFTOVERBITS$CHECKSUM_BINARY

if [ $DEBUG -eq 1 ]; then
	echo "CHECKSUM BYTE: $CHECKSUM_BYTE"
	echo "CHECKSUM BINARY: $CHECKSUM_BINARY"
	echo "LEFT OVER BITS: $LEFTOVERBITS" 
	echo "CHECKSUM: $CHECKSUM_BINARY" 
fi

echo "LAST WORD: $LAST_WORD" 

finalMnemonics=$BINARY_CONVERSION$CHECKSUM_BINARY

if [ $DEBUG -eq 0 ]; then
	# Download official BIP39 word list
	wget -o /dev/null -O bip39-english.txt https://raw.githubusercontent.com/bitcoin/bips/refs/heads/master/bip-0039/english.txt 
fi

echo -e "\n"

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

# Print inline seed words
printf "SEED WORDS:\n"
printf '=%.0s' $(seq 1 $((COLUMNS - 1))) "\n"
for i in $(seq 1 $((SEED_WORDS))); do
    printf "%s " "${finalMatrix[$i,2]}"
done
printf "\n"
printf '=%.0s' $(seq 1 $((COLUMNS - 1))) "\n\n"
