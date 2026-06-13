#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <sstream>
#include <windows.h>
#include <commdlg.h>

// Damit der Compiler weiss, dass er die Dialog-Bibliothek linken muss (fuer Visual Studio)
#pragma comment(lib, "comdlg32.lib")

struct Patch {
    std::string name;
    std::string aob;
    size_t offset;
    std::vector<uint8_t> patchBytes;
};

std::vector<Patch> patches = {
    {"FeatsCheck001", "40 ?? 56 57 48 ?? ?? ?? 48 ?? ?? ?? 4C ?? ??", 0, {0xC3, 0x90}},
    {"FeatsCheck002", "C6 ?? ?? ?? ?? ?? ?? 48 ?? ?? ?? ?? ?? ?? 48 ?? ?? 74 ?? C6 ?? ?? ?? ?? ?? ?? E8 ?? ?? ?? ?? B0 ??", 6, {0x01}},
    {"FeatsCheck003", "74 ?? 0F ?? ?? ?? ?? ?? ?? EB ?? 32 ?? 88 ?? ?? ?? ?? ??", 0, {0xEB}},
    {"FeatsCheck004", "C6 ?? ?? ?? ?? ?? ?? E9 ?? ?? ?? ?? 41 ?? ?? ?? 0F ?? ?? ?? ?? ?? 45 ?? ??", 6, {0x01}}
};

const char* ASCII_ART = R"(
  __  __  ____  _____  _  ___ _   _  ____ 
 |  \/  || __ )|  _ \ | |/ /_| \ | |/ ___|
 | |\/| ||  _ \| |_) || ' / | ||  \| | |  _ 
 | |  | || |_) |  _ < | . \ | || |\  | |_| |
 |_|  |_||____/|_| \_\|_|\_\|_||_| \_|\____|
                                            
      ~ Mina The Hollower Patcher ~
)";

// AOB in Byte-Muster und Maske (x = exakt, ? = wildcard) umwandeln
void ParseAOB(const std::string& aob, std::vector<uint8_t>& pattern, std::string& mask) {
    std::stringstream ss(aob);
    std::string byteStr;
    while (ss >> byteStr) {
        if (byteStr == "??" || byteStr == "?") {
            pattern.push_back(0);
            mask += "?";
        } else {
            pattern.push_back((uint8_t)std::stoul(byteStr, nullptr, 16));
            mask += "x";
        }
    }
}

// Sucht nach allen Vorkommen des Musters
std::vector<size_t> FindAllMatches(const std::vector<uint8_t>& data, const std::string& aob) {
    std::vector<uint8_t> pattern;
    std::string mask;
    ParseAOB(aob, pattern, mask);

    std::vector<size_t> matches;
    if (pattern.empty() || data.size() < pattern.size()) return matches;

    for (size_t i = 0; i <= data.size() - pattern.size(); ++i) {
        bool found = true;
        for (size_t j = 0; j < pattern.size(); ++j) {
            if (mask[j] == 'x' && data[i + j] != pattern[j]) {
                found = false;
                break;
            }
        }
        if (found) {
            matches.push_back(i);
        }
    }
    return matches;
}

std::string GetGameVersion(const std::vector<uint8_t>& data) {
    std::string versionStr = "Unknown";
    std::string revisionStr = "Unknown";

    // Main Version Scan (Length 12 bytes)
    auto v_matches = FindAllMatches(data, "56 65 72 2E 20 31 2E ?? 2E ?? ?? ??");
    if (!v_matches.empty()) {
        size_t start = v_matches[0];
        versionStr = "";
        for (int i = 0; i < 12; i++) {
            char c = (char)data[start + i];
            if (c != '\0') versionStr += c;
        }
        // Trimmen rechts
        versionStr.erase(versionStr.find_last_not_of(" \n\r\t") + 1);
    }

    // Revision Scan (Offset +20, Length 8 bytes)
    auto r_matches = FindAllMatches(data, "62 61 63 6B 74 72 61 63 65 2E 76 65 72 73 69 6F 6E 00 00 00 ?? ?? ?? ?? ?? ?? ?? ??");
    if (!r_matches.empty()) {
        size_t start = r_matches[0] + 20;
        revisionStr = "";
        for (int i = 0; i < 8; i++) {
            char c = (char)data[start + i];
            if (c != '\0') revisionStr += c;
        }
        revisionStr.erase(revisionStr.find_last_not_of(" \n\r\t") + 1);
    }

    return versionStr + " - " + revisionStr;
}

std::string OpenFileDialog() {
    OPENFILENAMEA ofn;
    CHAR szFile[MAX_PATH] = { 0 };
    ZeroMemory(&ofn, sizeof(OPENFILENAMEA));
    ofn.lStructSize = sizeof(OPENFILENAMEA);
    ofn.hwndOwner = NULL;
    ofn.lpstrFile = szFile;
    ofn.nMaxFile = sizeof(szFile);
    ofn.lpstrFilter = "Executables\0*.exe\0All Files\0*.*\0";
    ofn.nFilterIndex = 1;
    ofn.lpstrFileTitle = NULL;
    ofn.nMaxFileTitle = 0;
    ofn.lpstrInitialDir = NULL;
    ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_NOCHANGEDIR;

    if (GetOpenFileNameA(&ofn) == TRUE) {
        return std::string(ofn.lpstrFile);
    }
    return "";
}

int main() {
    SetConsoleTitleA("MinaTheHollowerPatcher by MBRKiNG");
    system("color 0A");

    std::cout << ASCII_ART << std::endl;
    std::cout << "===========================================================\n";
    std::cout << " Brought to you by MBRKiNG\n";
    std::cout << " Sources & Updates:\n";
    std::cout << " -> https://opencheattables.com\n";
    std::cout << " -> https://github.com/mbrking/CE-Tables\n";
    std::cout << "===========================================================\n\n";
    std::cout << "[*] Initializing patcher...\n\n";

    std::string filepath = OpenFileDialog();
    if (filepath.empty()) {
        std::cout << "[-] No file selected. Aborting.\n";
        system("pause");
        return 0;
    }

    std::cout << "[*] Selected file: " << filepath << "\n";

    std::string backup_path = filepath + ".bak";
    if (CopyFileA(filepath.c_str(), backup_path.c_str(), FALSE)) {
        std::cout << "[+] Backup created successfully: " << backup_path << "\n";
    } else {
        std::cout << "[-] Failed to create backup. Error code: " << GetLastError() << "\n";
        system("pause");
        return 1;
    }

    // Datei komplett in den Speicher laden
    std::ifstream file(filepath, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        std::cout << "[-] Failed to read file.\n";
        system("pause");
        return 1;
    }
    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);
    std::vector<uint8_t> content((size_t)size);
    if (!file.read((char*)content.data(), size)) {
        std::cout << "[-] Failed to read file data.\n";
        system("pause");
        return 1;
    }
    file.close();

    // Game Version Scanner
    std::string game_version = GetGameVersion(content);
    std::cout << "[*] Current Game Version: " << game_version << "\n\n";

    int patched_count = 0;

    for (const auto& p : patches) {
        std::vector<size_t> matches = FindAllMatches(content, p.aob);

        if (matches.size() == 1) {
            size_t patch_pos = matches[0] + p.offset;
            for (size_t i = 0; i < p.patchBytes.size(); ++i) {
                content[patch_pos + i] = p.patchBytes[i];
            }
            patched_count++;
            std::cout << "[+] " << p.name << " patched successfully.\n";
        } else if (matches.size() > 1) {
            std::cout << "[-] " << p.name << " FAILED: " << matches.size() << " AOB matches found! Signature is no longer unique.\n";
        } else {
            std::cout << "[-] " << p.name << " AOB not found.\n";
        }
    }

    if (patched_count > 0) {
        std::ofstream outfile(filepath, std::ios::binary);
        if (outfile.is_open()) {
            outfile.write((char*)content.data(), content.size());
            outfile.close();
            std::cout << "\n[+] SUCCESS: " << patched_count << "/" << patches.size() << " patches applied.\n";
        } else {
            std::cout << "[-] Failed to save patched file.\n";
        }
    } else {
        std::cout << "\n[-] No patches were applied.\n";
    }

    std::cout << "\nPress Enter to exit...";
    std::cin.get();
    return 0;
}