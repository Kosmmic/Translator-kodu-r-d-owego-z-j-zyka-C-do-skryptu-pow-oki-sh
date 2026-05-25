#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration / File paths
INPUT_FILE="test.c"
CLEAN_FILE="clean.tmp"
OUTPUT_FILE="program.sh"
DIAG_FILE="diagnostics.txt"

# Ensure clean state before execution (ignore errors if files do not exist)
rm -f "$CLEAN_FILE" "$OUTPUT_FILE" "$DIAG_FILE"

echo "=== STARTING TRANSPILER ==="

# Cleaning comments and additional spaces
grep -v '^[[:space:]]*//' "$INPUT_FILE" | grep -v '^[[:space:]]*$' > "$CLEAN_FILE"

# Adding header to the output file
echo "#!/bin/sh" > "$OUTPUT_FILE"

while read -r line; do
	line_no_semicolon=$(echo "$line" | sed 's/;[[:space:]]*$//')

	case "$line_no_semicolon" in
		int[[:space:]]*)
		 	# Translate 'int x = 5' to 'x=5'
			variable=$(echo "$line_no_semicolon" | sed 's/int[[:space:]]*//; s/[[:space:]]*=[[:space:]]*/=/')
			echo "$variable" >> "$OUTPUT_FILE"
			;;
		printf*)
			# Extract variable name from printf arguments
			variable_name=$(echo "$line_no_semicolon" | sed -n 's/.*,[[:space:]]*\([a-zA-Z0-9_]*\).*/\1/p')
			# Extract the raw format string inside quotes
			clean_text=$(echo "$line_no_semicolon" | sed 's/printf("//; s/".*//')
			# Replace C format specifier (%d) with Shell variable reference ($var)
			if [ -n "$variable_name" ]; then
				final_text=$(echo "$clean_text" | sed "s/%d/\$$variable_name/g")
			else
				final_text="$clean_text"
			fi
			
			echo "echo \"$final_text\"" >> "$OUTPUT_FILE"
			;;
		*)
			# Log unrecognized sequences to the diagnostics file
			echo "ERROR: Cannot translate this sequence: -> $line" >> "$DIAG_FILE"
			echo "[DIAGNOSTICS] Skipped unknown line."
			;;
	esac
done < "$CLEAN_FILE"

# Cleanup temporary files
rm -f "$CLEAN_FILE"

echo "===TRANSPILATION COMPLETE==="
echo "Result script: $OUTPUT_FILE"
echo "Diagnostic logs: $DIAG_FILE"
