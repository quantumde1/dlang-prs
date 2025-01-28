module gui.gui;

import std.stdio;
import std.file;
import std.string;
import raylib;
import prs.compress;
import prs.decompress;
import prs.estimate;

void mainUIDrawer() {
    writeln("GUI started");
    int screenWidth = 800;
    int screenHeight = 600;
    InitWindow(screenWidth, screenHeight, "PRS GUI");
    SetTargetFPS(25);

    string currentDirectory;
    version (Posix) { currentDirectory = "/"; }
    version (Windows) { currentDirectory = "C:\\"; }

    string[] files;
    bool showFiles;
    string selectedFile;
    files = listFiles(currentDirectory);
    showFiles = true;
    bool reloadNeeded;
    bool isFile;
    // Переменная для прокрутки
    int scrollOffset = 0;

    while (!WindowShouldClose()) {
        // Обработка прокрутки колесиком мыши
        float wheelMove = GetMouseWheelMove();
        if (wheelMove != 0) {
            scrollOffset -= cast(int)(wheelMove * 20); // 20 - скорость прокрутки
            scrollOffset = scrollOffset < 0 ? 0 : scrollOffset; // Ограничиваем прокрутку сверху
        }
        if (isFile == true) {
            DrawText(toStringz("left arrow - compress to .prs\nright arrow - decompress to .out\nbackspace - prev.dir"), screenWidth - MeasureText(toStringz("left arrow - compress to .prs\nright arrow - decompress to .out\nbackspace - prev.dir"), 20) - 10, 10, 20, Colors.WHITE);
        } else {
            DrawText(toStringz("backspace - prev.dir\nF5 - update"), screenWidth - MeasureText(toStringz("backspace - prev.dir\nF5 - update"), 20) - 10, 10, 20, Colors.WHITE);
        }
        DrawText("PRS unpacker by quantumde1",
            screenWidth - MeasureText("PRS unpacker by quantumde1", 20),
            screenHeight - 20, 20, Colors.WHITE);
        // Обработка клика мышью
        if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
            Vector2 mousePosition = GetMousePosition();
            if (mousePosition.x >= 10 && mousePosition.x <= 790 && mousePosition.y >= 50 && mousePosition.y <= 550) {

                int index = cast(int)((mousePosition.y - 50 + scrollOffset) / 20);
                if (index >= 0 && index < files.length) {
                    selectedFile = files[index];
                    writeln("Selected file: ", selectedFile);
                    reloadNeeded = true;
                }
            }
        }
        // Обновление списка файлов при нажатии F5 или необходимости перезагрузки
        if (IsKeyPressed(KeyboardKey.KEY_F5) || reloadNeeded) {
            if (isDir(selectedFile)) {
                files = listFiles(selectedFile);
                showFiles = true;
                isFile = false;
                scrollOffset = 0; // Сброс прокрутки при обновлении списка
            } else {
                isFile = true;
            }
            reloadNeeded = false;
        }
        if (isFile && IsKeyPressed(KeyboardKey.KEY_LEFT)) {
            string inputFile = selectedFile;
            string outputFile = selectedFile~".prs";
            byte[] sourceData = cast(byte[]) std.file.read(inputFile);
            byte[] compressedData = compress(sourceData);
            std.file.write(outputFile, compressedData);
            writeln("Pack ended, data written to: ", outputFile);
        }
        if (isFile && IsKeyPressed(KeyboardKey.KEY_RIGHT)) {
            string inputFile = selectedFile;
            string outputFile = selectedFile~".out";
            //reads input file
            byte[] sourceData = cast(byte[]) std.file.read(inputFile);
            //decompressing to byte array from initially readed data
            byte[] decompressedData = decompress(sourceData);
            //writing data to file
            std.file.write(outputFile, decompressedData);
            //exit
            writeln("Unpack ended, data written to: ", outputFile);
        }
        // Возврат к предыдущей директории при нажатии Backspace
        if (IsKeyPressed(KeyboardKey.KEY_BACKSPACE)) {
            string path = selectedFile;
            int lastSlashIndex = cast(int)path.lastIndexOf('/');
            if (lastSlashIndex != -1) {
                path = path[0 .. lastSlashIndex];
            }
            selectedFile = path;
            reloadNeeded = true;
        }

        // Начало отрисовки
        BeginDrawing();
        ClearBackground(Colors.BLACK);

        // Отрисовка списка файлов с учетом прокрутки
        if (showFiles) {
            for (int i = 0; i < files.length; i++) {
                int yPos = 50 + i * 20 - scrollOffset;
                if (yPos >= 50 && yPos <= 550) { // Отрисовываем только видимые элементы
                    DrawText(toStringz(files[i]), 10, yPos, 20, Colors.WHITE);
                }
            }
        }

        // Отрисовка выбранного файла
        if (selectedFile.length > 0) {
            if (!isFile) DrawText(toStringz("Selected: " ~ selectedFile), 10, 10, 20, Colors.GREEN);
            if (isFile) {
                string[] parts = selectedFile.split("/");
                string lastWord = parts[$ - 1]; // Получаем последний элемент массива
                DrawText(toStringz("Selected: " ~ lastWord), 10, 10, 20, Colors.GREEN);
            }
        }

        EndDrawing();
    }

    CloseWindow();
}

string[] listFiles(string directory) {
    string[] files;
    foreach (entry; dirEntries(directory, SpanMode.shallow)) {
        files ~= entry.name;
    }
    return files;
}

string dirName(string path) {
    return path.dirName;
}
