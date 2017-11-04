/*
** Pretty6502
**
** by Oscar Toledo G.
**
** © Copyright 2017 Oscar Toledo G.
**
** Creation date: Nov/03/2017.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define VERSION "v0.1"
int tabs;

/*
** Request space in line
*/
void request_space(FILE *output, int *current, int new, int force)
{

	/*
	** If already exceeded space...
	*/
	if (*current >= new) {
		if (force)
			fputc(' ', output);	
		(*current)++;
		return;
	}

	/*
	** Advance one step at a time
	*/
	while (1) {
		if (tabs == 0) {
			fputc(' ', output);
			(*current)++;
		} else {
			fputc('\t', output);
			*current = (*current + tabs) / tabs * tabs;
		}
		if (*current >= new) 
			return;
	}
}

/*
** Main program
*/
int main(int argc, char *argv[])
{
	int c;
	int style;
	int start_mnemonic;
	int start_operand;
	int start_comment;
	int align_comment;
	FILE *input;
	FILE *output;
	char line[4096];
	int input_lines;
	int allocation;
	char *data;
	int current_line;
	int next_position;
	char *p;
	char *p1;
	char *p2;
	int current_column;
	int request;

	/*
	** Show usage if less than 3 arguments (program name counts as one)
	*/
	if (argc < 3) {
		fprintf(stderr, "\n");
		fprintf(stderr, "Pretty6502 " VERSION " by Oscar Toledo G. http://nanochess.org/\n");
		fprintf(stderr, "\n");
		fprintf(stderr, "Usage:\n");
		fprintf(stderr, "    pretty6502 [args] input.asm output.asm\n");
		fprintf(stderr, "\n");
		fprintf(stderr, "DON'T USE SAME OUTPUT FILE AS INPUT, though it's possible,\n");
		fprintf(stderr, "you can DAMAGE YOUR SOURCE if this program has bugs.\n");
		fprintf(stderr, "\n");
		fprintf(stderr, "Arguments:\n");
		fprintf(stderr, "    -s0       Code in four columns (default)\n");
		fprintf(stderr, "              label: mnemonic operand comment\n");
		fprintf(stderr, "    -s1       Code in three columns\n");
		fprintf(stderr, "              label: mnemonic+operand comment\n");
		fprintf(stderr, "    -m8       Start of mnemonic column (default)\n");
		fprintf(stderr, "    -o16      Start of operand column (default)\n");
		fprintf(stderr, "    -c32      Start of comment column (default)\n");
		fprintf(stderr, "    -t8       Use tabs of size 8 to reach column\n");
		fprintf(stderr, "    -t0       Use spaces to align (default)\n");
		fprintf(stderr, "    -a0       Align comments to nearest column\n");
		fprintf(stderr, "    -a1       Comments at line start are aligned\n");
		fprintf(stderr, "              to mnemonic (default)\n");
		fprintf(stderr, "\n");
		fprintf(stderr, "Assumes all your labels are at start of line and there is space\n");
		fprintf(stderr, "before mnemonic.\n");
		fprintf(stderr, "\n");
		fprintf(stderr, "Accepts any assembler file where ; means comment\n");
		fprintf(stderr, "[label] mnemonic [operand] ; comment\n");
		exit(1);
	}

	/*
	** Default settings
	*/
	style = 0;
	start_mnemonic = 8;
	start_operand = 16;
	start_comment = 32;
	tabs = 0;
	align_comment = 1;

	/*
	** Process arguments
	*/
	c = 1;
	while (c < argc - 2) {
		if (argv[c][0] != '-') {
			fprintf(stderr, "Bad argument\n");
			exit(1);
		}
		switch (argv[c][1]) {
			case 's':	/* Style */
				style = atoi(&argv[c][2]);
				if (style != 0 && style != 1) {
					fprintf(stderr, "Bad style code: %d\n", style);	
					exit(1);
				}
				break;
			case 'm':	/* Mnemonic start */
				start_mnemonic = atoi(&argv[c][2]);
				break;
			case 'o':	/* Operand start */
				start_operand = atoi(&argv[c][2]);
				break;
			case 'c':	/* Comment start */
				start_comment = atoi(&argv[c][2]);
				break;
			case 't':	/* Tab size */
				tabs = atoi(&argv[c][2]);
				break;
			case 'a':	/* Comment alignment */
				align_comment = atoi(&argv[c][2]);
				if (align_comment != 0 && align_comment != 1) {
					fprintf(stderr, "Bad comment alignment: %d\n", align_comment);
					exit(1);
				}
				break;
			default:	/* Other */
				fprintf(stderr, "Unknown argument: %c\n", argv[c][1]);
				exit(1);
		}
		c++;
	}

	/*
	** Validate constraints
	*/
	if (style == 1) {
		if (start_mnemonic > start_comment) {
			fprintf(stderr, "Operand error: -m%d > -c%d\n", start_mnemonic, start_comment);
			exit(1);
		}
		start_operand = start_mnemonic;
	} else if (style == 0) {
		if (start_mnemonic > start_operand) {
			fprintf(stderr, "Operand error: -m%d > -o%d\n", start_mnemonic, start_operand);
			exit(1);
		}
		if (start_operand > start_comment) {
			fprintf(stderr, "Operand error: -o%d > -c%d\n", start_operand, start_comment);
			exit(1);
		}
	}
	if (tabs > 0) {
		if (start_mnemonic % tabs) {
			fprintf(stderr, "Operand error: -m%d isn't a multiple of %d\n", start_mnemonic, tabs);
			exit(1);
		}
		if (start_operand % tabs) {
			fprintf(stderr, "Operand error: -m%d isn't a multiple of %d\n", start_operand, tabs);
			exit(1);
		}
		if (start_comment % tabs) {
			fprintf(stderr, "Operand error: -m%d isn't a multiple of %d\n", start_comment, tabs);
			exit(1);
		}
	}

	/*
	** Open input file, measure it and read it into buffer
	*/
	input = fopen(argv[c], "r");
	if (input == NULL) {
		fprintf(stderr, "Unable to open input file: %s\n", argv[c]);
		exit(1);
	}
	fprintf(stderr, "Processing %s...\n", argv[c]);
	input_lines = 0;
	allocation = 0;
	while (fgets(line, sizeof(line) - 1, input)) {
		allocation += strlen(line) + 1;
		input_lines++;
	}
	fclose(input);
	data = malloc(allocation);
	if (data == NULL) {
		fprintf(stderr, "Unable to allocate memory\n");
		exit(1);
	}
	input = fopen(argv[c], "r");
	if (input == NULL) {
		fprintf(stderr, "Unable to open input file: %s\n", argv[c]);
		exit(1);
	}
	current_line = 0;
	next_position = 0;
	while (fgets(line, sizeof(line) - 1, input)) {
		if (current_line >= input_lines || next_position + strlen(line) + 1 > allocation) {
			fprintf(stderr, "Buuurp! the source file grew!\n");
			fclose(input);
			exit(1);
		}
		strcpy(data + next_position, line);
		next_position += strlen(line) + 1;
		current_line++;
	}
	fclose(input);

	/*
	** Now generate output file
	*/
	c++;
	output = fopen(argv[c], "w");
	if (output == NULL) {
		fprintf(stderr, "Unable to open output file: %s\n", argv[c]);
		exit(1);
	}
	p = data;
	for (input_lines = 0; input_lines < current_line; input_lines++) {
		current_column = 0;
		p1 = p;
		if (*p1 && !isspace(*p1) && *p1 != ';') {	/* Label */
			while (*p1 && !isspace(*p1) && *p1 != ';')
				p1++;
			fwrite(p, sizeof(char), p1 - p, output);
			current_column = p1 - p;
		} else {
			current_column = 0;
		}
		while (*p1 && isspace(*p1))
			p1++;
		if (*p1 && *p1 != ';') {	/* Mnemonic */
			if (*p1 == '=')
				request = start_operand;
			else
				request = start_mnemonic;
			request_space(output, &current_column, request, 1);
			p2 = p1;
			while (*p2 && !isspace(*p2))
				p2++;
			fwrite(p1, sizeof(char), p2 - p1, output);
			current_column += p2 - p1;
			p1 = p2;
			while (*p1 && isspace(*p1))
				p1++;
			if (*p1 && *p1 != ';') {	/* Operand */
				request = start_operand;
				request_space(output, &current_column, request, 1);
				p2 = p1;
				while (*p2 && *p2 != ';' && *p2 != '\r' && *p2 != '\n') {
					if (*p2 == '"') {
						p2++;
						while (*p2 && *p2 != '"')
							p2++;
						p2++;
					} else if (*p2 == '\'') {
						p2++;
						while (*p2 && *p2 != '"')
							p2++;
						p2++;
					} else {
						p2++;
					}
				}
				while (p2 > p1 && isspace(*(p2 - 1)))
					p2--;
				fwrite(p1, sizeof(char), p2 - p1, output);
				current_column += p2 - p1;
				p1 = p2;
				while (*p1 && isspace(*p1))
					p1++;
			}
		}
		if (*p1 == ';') {	/* Comment */
			if (current_column == 0)
				request = 0;
			else if (current_column < start_mnemonic)
				request = start_mnemonic;
			else
				request = start_comment;
			if (current_column == 0 && align_comment == 1)
				request = start_mnemonic;
			request_space(output, &current_column, request, 0);
			p2 = p1;
			while (*p2 && *p2 != '\r' && *p2 != '\n')
				p2++;
			while (p2 > p1 && isspace(*(p2 - 1)))
				p2--;
			fwrite(p1, sizeof(char), p2 - p1, output);
			fputc('\n', output);
			current_column += p2 - p1;
			while (*p++) ;
			continue;
		}
		fputc('\n', output);
		while (*p++) ;
	}
	fclose(output);	
	free(data);
	exit(0);
}
