/**
 * String Utilities - Safe String Operations
 * 
 * This file provides safe wrappers for string operations that crash on null strings in Vala.
 * All methods handle null inputs gracefully and return safe defaults.
 */

namespace EnhancedNetwork {
    
    /**
     * Safe string utilities to prevent crashes on null strings
     */
    public class StringUtils {
        
        /**
         * Safe string replace - handles null strings
         */
        public static string safe_replace(string? str, string old_substring, string new_substring) {
            if (str == null) return "";
            return str.replace(old_substring, new_substring);
        }
        
        /**
         * Safe string to lowercase - handles null strings
         */
        public static string safe_down(string? str) {
            if (str == null) return "";
            return str.down();
        }
        
        /**
         * Safe string to uppercase - handles null strings
         */
        public static string safe_up(string? str) {
            if (str == null) return "";
            return str.up();
        }
        
        /**
         * Safe string contains - handles null strings
         */
        public static bool safe_contains(string? str, string substring) {
            if (str == null) return false;
            return str.contains(substring);
        }
        
        /**
         * Safe string has_prefix - handles null strings
         */
        public static bool safe_has_prefix(string? str, string prefix) {
            if (str == null) return false;
            return str.has_prefix(prefix);
        }
        
        /**
         * Safe string has_suffix - handles null strings
         */
        public static bool safe_has_suffix(string? str, string suffix) {
            if (str == null) return false;
            return str.has_suffix(suffix);
        }
        
        /**
         * Safe string substring - handles null strings
         */
        public static string safe_substring(string? str, long offset, long len = -1) {
            if (str == null) return "";
            if (offset >= str.length) return "";
            if (len == -1) {
                return str.substring(offset);
            }
            return str.substring(offset, len);
        }
        
        /**
         * Safe string strip - handles null strings
         */
        public static string safe_strip(string? str) {
            if (str == null) return "";
            return str.strip();
        }
        
        /**
         * Safe string split - handles null strings
         */
        public static string[] safe_split(string? str, string delimiter) {
            if (str == null) return new string[0];
            return str.split(delimiter);
        }
        
        /**
         * Safe string concatenation - handles null strings
         */
        public static string safe_concat(string? str1, string? str2) {
            return (str1 ?? "") + (str2 ?? "");
        }
        
        /**
         * Safe printf - handles null format strings and arguments
         */
        public static string safe_printf(string? format, ...) {
            if (format == null) return "";
            var args = va_list();
            return format.vprintf(args);
        }
        
        /**
         * Get non-null string - returns empty string if null
         */
        public static string non_null(string? str) {
            return str ?? "";
        }
    }
}
