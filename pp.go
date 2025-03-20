package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strings"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run main.go <filename>")
		return
	}

	filename := os.Args[1]
	data, err := os.ReadFile(filename)
	if err != nil {
		fmt.Println("Error reading file:", err)
		return
	}

	text := string(data)
	lastGlobalLabel := ""

	localLabelRegex := regexp.MustCompile(`(?m)^\s*(\.[a-z_]+)\b:`)
	allLocalLabels := localLabelRegex.FindAllStringSubmatch(text, -1)
	localLabels := make(map[string]bool)
	for _, match := range allLocalLabels {
		if len(match) > 1 {
			localLabels[match[1]] = true
		}
	}

	scanner := bufio.NewScanner(strings.NewReader(text))
	for scanner.Scan() {
		line := scanner.Text()
		commentIndex := strings.Index(line, ";")
		if commentIndex == 0 {
			continue
		}

		if commentIndex > 0 {
			line = strings.TrimRight(line[:commentIndex], " ")
		}

		if line == "" {
			continue
		}

		labelRegex := regexp.MustCompile(`(^|\s)([A-Za-z][A-Za-z_.]*)\b:`)
		if matches := labelRegex.FindStringSubmatch(line); matches != nil {
			lastGlobalLabel = matches[2]
		}

		lineLocalLabelRegex := regexp.MustCompile(`(^|\s|,)(\.[a-z_]+)\b`)
		line = lineLocalLabelRegex.ReplaceAllStringFunc(line, func(match string) string {
			parts := lineLocalLabelRegex.FindStringSubmatch(match)
			if len(parts) > 2 && localLabels[parts[2]] {
				return parts[1] + lastGlobalLabel + parts[2]
			}
			return match
		})

		fmt.Println(line)
	}
}
