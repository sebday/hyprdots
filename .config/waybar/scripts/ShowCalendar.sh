#!/bin/bash

# Define some colors using true color ANSI escape sequences
CURRENT_MONTH_COLOR='\033[38;2;180;249;248m' # #b4f9f8 for ncal's current month
OTHER_MONTH_COLOR='\033[38;2;31;35;53m'    # #1f2335 for other months
CURRENT_DATE_HL_COLOR='\033[38;2;255;199;119m' # #ffc777 for today's actual date
NC='\033[0m' # No color

# Script's current view for ncal
view_month=$(date +%m)
view_year=$(date +%Y)

# Actual current date
actual_today_day_num=$(date +%e | sed 's/ //g') # Day as number, e.g., "7", "17"
actual_today_month_num=$(date +%m)
actual_today_year_num=$(date +%Y)

is_initial_display=1

# Function to ensure cursor is shown on exit
trap 'echo -ne "\033[?25h"' EXIT

# Function to display calendar
display_cal() {
    clear
    echo -ne '\033[?25l' # Hide cursor
    local cal_output
    # Get calendar output, NO ncal highlighting (-h), 3 months, bare format (-b)
    cal_output=$(ncal -h -b "$1" "$2" -3)

    # Use awk to colorize the output, add separators, and highlight current date
    echo "$cal_output" | awk \
        -v cm_color="$CURRENT_MONTH_COLOR" \
        -v om_color="$OTHER_MONTH_COLOR" \
        -v cdate_hl_color="$CURRENT_DATE_HL_COLOR" \
        -v nc="$NC" \
        -v initial_load="$is_initial_display" \
        -v ncal_disp_m="$1" \
        -v ncal_disp_y="$2" \
        -v actual_d="$actual_today_day_num" \
        -v actual_m="$actual_today_month_num" \
        -v actual_y="$actual_today_year_num" \
    '
    BEGIN { processed_line_nr = 0 }

    initial_load == "1" && NR == 1 {next} # Skip the overall year line from ncal on initial script load

    { 
    
        processed_line_nr++
        
        s1_data = substr($0, 1, 22)  
        s2_data = substr($0, 23, 20) 
        s3_data = substr($0, 43)     

        if (processed_line_nr == 1) { 
   
            print om_color s1_data nc cm_color s2_data nc om_color s3_data nc
            
 
            sep_s1 = "--------------------  " # 20 dashes + 2 spaces
            sep_s2 = "--------------------"   # 20 dashes
            sep_s3 = "  --------------------" # 2 spaces + 20 dashes
            print om_color sep_s1 nc cm_color sep_s2 nc om_color sep_s3 nc
            
        } else { 

            middle_segment_output = cm_color s2_data nc

            if (ncal_disp_m == actual_m && ncal_disp_y == actual_y && processed_line_nr > 2) {
                day_to_find_in_ncal = sprintf("%2s", actual_d)
                
                pos = index(s2_data, day_to_find_in_ncal)
                if (pos > 0) {

                    valid_match = 1
                    if (pos > 1 && substr(s2_data, pos-1, 1) ~ /[0-9]/) {
                        valid_match = 0 
                    }
                    if (pos + length(day_to_find_in_ncal) <= length(s2_data) && substr(s2_data, pos + length(day_to_find_in_ncal), 1) ~ /[0-9]/) {
                        valid_match = 0 
                    }

                    if (valid_match) {
                        before_highlight = substr(s2_data, 1, pos - 1)
                        highlighted_day_str = substr(s2_data, pos, length(day_to_find_in_ncal))
                        after_highlight = substr(s2_data, pos + length(day_to_find_in_ncal))
                        
                        middle_segment_output = cm_color before_highlight nc cdate_hl_color highlighted_day_str nc cm_color after_highlight nc
                    }
                }
            }
            print om_color s1_data nc middle_segment_output om_color s3_data nc
        }
    }
    '

    # If it was the initial display, set flag to 0 for subsequent calls
    if [ "$is_initial_display" -eq 1 ]; then
        is_initial_display=0
    fi
}

# Hide cursor before first display
echo -ne '\033[?25l'
display_cal "$view_month" "$view_year"

while true; do
    # Read a single character, raw, silent, with a timeout for escape sequences
    read -rsn1 -t 0.1 key

    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.1 esc_seq
        key+="$esc_seq" 
    fi

    case "$key" in
        $'\x1b[D') # Left arrow
            base_date_for_calc="$view_year-$view_month-01"
            new_m_temp=$(date -d "$base_date_for_calc -1 month" +%m 2>/dev/null)
            new_y_temp=$(date -d "$base_date_for_calc -1 month" +%Y 2>/dev/null)

            if [[ -n "$new_m_temp" && -n "$new_y_temp" ]]; then
                view_month="$new_m_temp"
                view_year="$new_y_temp"
                display_cal "$view_month" "$view_year"
            fi
            ;;
        $'\x1b[C') # Right arrow
            base_date_for_calc="$view_year-$view_month-01"
            new_m_temp=$(date -d "$base_date_for_calc +1 month" +%m 2>/dev/null)
            new_y_temp=$(date -d "$base_date_for_calc +1 month" +%Y 2>/dev/null)

            if [[ -n "$new_m_temp" && -n "$new_y_temp" ]]; then
                view_month="$new_m_temp"
                view_year="$new_y_temp"
                display_cal "$view_month" "$view_year"
            fi
            ;;
        'q') # Quit
            clear
            echo -ne '\033[?25h'
            break
            ;;
    esac
done 