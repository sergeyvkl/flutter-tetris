import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(TetrisApp(prefs: prefs));
}

class TetrisApp extends StatelessWidget {
  final SharedPreferences prefs;
  
  const TetrisApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Тетрис+',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TetrisGame(prefs: prefs),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TetrisGame extends StatefulWidget {
  final SharedPreferences prefs;
  
  const TetrisGame({super.key, required this.prefs});

  @override
  State<TetrisGame> createState() => _TetrisGameState();
}

class _TetrisGameState extends State<TetrisGame> with SingleTickerProviderStateMixin {
  // Настройки игры (с возможностью изменения)
  int rowLength = 10;
  int colLength = 20;
  int startSpeed = 500;
  bool soundEnabled = true;
  
  // Игровые переменные
  int currentScore = 0;
  int highScore = 0;
  bool isGameOver = false;
  bool isPaused = false;
  List<List<int>> currentPiece = [];
  List<List<int>> nextPiece = [];
  int currentRow = 0;
  int currentCol = 0;
  List<List<int>> gameBoard = [];
  
  // Для анимации
  late AnimationController _animationController;
  List<int> _clearingLines = [];
  bool _isAnimating = false;
  
  // Для звуков
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, String> _soundEffects = {
    'rotate': 'sounds/rotate.mp3',
    'move': 'sounds/move.mp3',
    'drop': 'sounds/drop.mp3',
    'clear': 'sounds/clear.mp3',
    'gameover': 'sounds/gameover.mp3',
  };
  
  // Таймер игры
  Timer? _timer;
  int _speed = 500;
  
  // Цвета фигур
  final Map<int, Color> pieceColors = {
    1: Colors.red,
    2: Colors.green,
    3: Colors.blue,
    4: Colors.yellow,
    5: Colors.purple,
    6: Colors.orange,
    7: Colors.cyan,
  };
  
  // Фигуры тетриса
  final List<List<List<int>>> pieces = [
    [[1, 1, 1, 1]],
    [[2, 2], [2, 2]],
    [[0, 3, 0], [3, 3, 3]],
    [[4, 0], [4, 0], [4, 4]],
    [[0, 5], [0, 5], [5, 5]],
    [[0, 6, 6], [6, 6, 0]],
    [[7, 7, 0], [0, 7, 7]],
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadSettings();
    _loadHighScore();
    _initSounds();
    startGame();
  }

  Future<void> _initSounds() async {
    await _audioPlayer.setSource(AssetSource(_soundEffects['move']!));
  }

  Future<void> _playSound(String sound) async {
    if (!soundEnabled) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(_soundEffects[sound]!));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      rowLength = widget.prefs.getInt('rowLength') ?? 10;
      colLength = widget.prefs.getInt('colLength') ?? 20;
      startSpeed = widget.prefs.getInt('startSpeed') ?? 500;
      soundEnabled = widget.prefs.getBool('soundEnabled') ?? true;
      _speed = startSpeed;
    });
  }

  Future<void> _saveSettings() async {
    await widget.prefs.setInt('rowLength', rowLength);
    await widget.prefs.setInt('colLength', colLength);
    await widget.prefs.setInt('startSpeed', startSpeed);
    await widget.prefs.setBool('soundEnabled', soundEnabled);
  }

  Future<void> _loadHighScore() async {
    setState(() {
      highScore = widget.prefs.getInt('highScore') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (currentScore > highScore) {
      await widget.prefs.setInt('highScore', currentScore);
      setState(() {
        highScore = currentScore;
      });
    }
  }

  void startGame() {
    _timer?.cancel();
    setState(() {
      isGameOver = false;
      currentScore = 0;
      _speed = startSpeed;
      gameBoard = List.generate(
        colLength,
        (i) => List.generate(rowLength, (j) => 0),
      );
      spawnNewPiece();
      _timer = Timer.periodic(Duration(milliseconds: _speed), (timer) {
        if (!isPaused && !isGameOver && !_isAnimating) {
          moveDown();
        }
      });
    });
  }

  void spawnNewPiece() {
    Random rand = Random();
    
    if (nextPiece.isNotEmpty) {
      currentPiece = nextPiece;
    } else {
      currentPiece = pieces[rand.nextInt(pieces.length)];
    }
    
    nextPiece = pieces[rand.nextInt(pieces.length)];
    currentRow = 0;
    currentCol = (rowLength ~/ 2) - (currentPiece[0].length ~/ 2);
    
    if (checkCollision(currentRow, currentCol, currentPiece)) {
      _timer?.cancel();
      isGameOver = true;
      _playSound('gameover');
      _saveHighScore();
    }
  }

  bool checkCollision(int row, int col, List<List<int>> piece) {
    for (int i = 0; i < piece.length; i++) {
      for (int j = 0; j < piece[i].length; j++) {
        if (piece[i][j] != 0) {
          int newRow = row + i;
          int newCol = col + j;
          
          if (newRow >= colLength || 
              newCol < 0 || 
              newCol >= rowLength || 
              (newRow >= 0 && gameBoard[newRow][newCol] != 0)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void mergePiece() {
    for (int i = 0; i < currentPiece.length; i++) {
      for (int j = 0; j < currentPiece[i].length; j++) {
        if (currentPiece[i][j] != 0) {
          int newRow = currentRow + i;
          int newCol = currentCol + j;
          if (newRow >= 0) {
            gameBoard[newRow][newCol] = currentPiece[i][j];
          }
        }
      }
    }
    _playSound('drop');
  }

  void clearLines() {
    _clearingLines.clear();
    
    for (int i = colLength - 1; i >= 0; i--) {
      bool lineComplete = true;
      for (int j = 0; j < rowLength; j++) {
        if (gameBoard[i][j] == 0) {
          lineComplete = false;
          break;
        }
      }
      
      if (lineComplete) {
        _clearingLines.add(i);
      }
    }
    
    if (_clearingLines.isNotEmpty) {
      _playSound('clear');
      _startClearAnimation();
    } else {
      spawnNewPiece();
    }
  }

  void _startClearAnimation() {
    setState(() {
      _isAnimating = true;
    });
    
    _animationController.reset();
    _animationController.forward().then((_) {
      _finishClearingLines();
    });
  }

  void _finishClearingLines() {
    int linesCleared = _clearingLines.length;
    
    // Удаляем линии
    for (int line in _clearingLines) {
      gameBoard.removeAt(line);
    }
    
    // Добавляем новые пустые линии сверху
    for (int i = 0; i < linesCleared; i++) {
      gameBoard.insert(0, List.generate(rowLength, (index) => 0));
    }
    
    // Обновляем счёт
    setState(() {
      currentScore += linesCleared * 100 * linesCleared; // Бонус за несколько линий
      _speed = max(100, _speed - 20);
      _isAnimating = false;
      _clearingLines.clear();
    });
    
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _speed), (timer) {
      if (!isPaused && !isGameOver && !_isAnimating) {
        moveDown();
      }
    });
    
    spawnNewPiece();
  }

  void moveLeft() {
    if (!isPaused && !isGameOver && !_isAnimating) {
      if (!checkCollision(currentRow, currentCol - 1, currentPiece)) {
        setState(() {
          currentCol--;
        });
        _playSound('move');
      }
    }
  }

  void moveRight() {
    if (!isPaused && !isGameOver && !_isAnimating) {
      if (!checkCollision(currentRow, currentCol + 1, currentPiece)) {
        setState(() {
          currentCol++;
        });
        _playSound('move');
      }
    }
  }

  void moveDown() {
    if (!isPaused && !isGameOver && !_isAnimating) {
      if (!checkCollision(currentRow + 1, currentCol, currentPiece)) {
        setState(() {
          currentRow++;
        });
      } else {
        mergePiece();
        clearLines();
      }
    }
  }

  void rotatePiece() {
    if (!isPaused && !isGameOver && !_isAnimating) {
      List<List<int>> rotated = List.generate(
        currentPiece[0].length,
        (i) => List.generate(currentPiece.length, (j) => 0),
      );
      
      for (int i = 0; i < currentPiece.length; i++) {
        for (int j = 0; j < currentPiece[i].length; j++) {
          rotated[j][currentPiece.length - 1 - i] = currentPiece[i][j];
        }
      }
      
      if (!checkCollision(currentRow, currentCol, rotated)) {
        setState(() {
          currentPiece = rotated;
        });
        _playSound('rotate');
      }
    }
  }

  void togglePause() {
    setState(() {
      isPaused = !isPaused;
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Настройки игры'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSettingSlider(
                      'Ширина поля: $rowLength',
                      rowLength.toDouble(),
                      6,
                      15,
                      (value) {
                        setState(() {
                          rowLength = value.toInt();
                        });
                      },
                    ),
                    _buildSettingSlider(
                      'Высота поля: $colLength',
                      colLength.toDouble(),
                      15,
                      30,
                      (value) {
                        setState(() {
                          colLength = value.toInt();
                        });
                      },
                    ),
                    _buildSettingSlider(
                      'Начальная скорость: ${startSpeed}ms',
                      startSpeed.toDouble(),
                      100,
                      1000,
                      (value) {
                        setState(() {
                          startSpeed = value.toInt();
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Звуковые эффекты'),
                      value: soundEnabled,
                      onChanged: (value) {
                        setState(() {
                          soundEnabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    _saveSettings();
                    Navigator.pop(context);
                    startGame();
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSettingSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      children: [
        Text(label),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          label: value.toInt().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Панель счёта и управления
          Padding(
            //padding: const EdgeInsets.all(16.0), //16
            padding: const EdgeInsets.fromLTRB(16, 45, 16, 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const Text(
                      'Счёт',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      '$currentScore',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Рекорд',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      '$highScore',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
                Column(
                  children: [
                    //const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: togglePause,
                      child: Text(isPaused ? 'Продолжить' : 'Пауза'),
                    ),
                    const SizedBox(height: 3 ),
                    ElevatedButton(
                      onPressed: isGameOver ? startGame : null,
                      child: const Text('Новая игра'),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white, size: 30),
                  onPressed: _showSettingsDialog,
                ),
              ],
            ),
          ),
          
          // Игровое поле и следующая фигура
          Expanded(
            child: Row(
              children: [
                // Игровое поле
                Expanded(
                  flex: 3,
                  child: Container(
                    //margin: const EdgeInsets.all(8.0),
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 25),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double cellSize = constraints.maxWidth / rowLength;
                        return Stack(
                          children: [
                            // Фон игрового поля
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: rowLength,
                                childAspectRatio: 1,
                              ),
                              itemCount: rowLength * colLength,
                              itemBuilder: (context, index) {
                                int row = index ~/ rowLength;
                                int col = index % rowLength;
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[800]!),
                                  ),
                                );
                              },
                            ),
                            
                            // Зафиксированные фигуры
                            for (int i = 0; i < colLength; i++)
                              for (int j = 0; j < rowLength; j++)
                                if (gameBoard[i][j] != 0)
                                  Positioned(
                                    left: j * cellSize,
                                    top: i * cellSize,
                                    child: Container(
                                      width: cellSize,
                                      height: cellSize,
                                      decoration: BoxDecoration(
                                        color: _clearingLines.contains(i)
                                            ? Colors.white.withOpacity(_animationController.value)
                                            : pieceColors[gameBoard[i][j]],
                                        border: Border.all(color: Colors.white),
                                      ),
                                    ),
                                  ),
                            
                            // Текущая фигура
                            if (!_isAnimating)
                              for (int i = 0; i < currentPiece.length; i++)
                                for (int j = 0; j < currentPiece[i].length; j++)
                                  if (currentPiece[i][j] != 0 && currentRow + i >= 0)
                                    Positioned(
                                      left: (currentCol + j) * cellSize,
                                      top: (currentRow + i) * cellSize,
                                      child: Container(
                                        width: cellSize,
                                        height: cellSize,
                                        decoration: BoxDecoration(
                                          color: pieceColors[currentPiece[i][j]],
                                          border: Border.all(color: Colors.white),
                                        ),
                                      ),
                                    ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                
                // Панель следующей фигуры и управления
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      const Text(
                        'Следующая:',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      // Отображение следующей фигуры
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double cellSize = constraints.maxWidth / 4;
                            return Center(
                              child: Stack(
                                children: [
                                  for (int i = 0; i < nextPiece.length; i++)
                                    for (int j = 0; j < nextPiece[i].length; j++)
                                      if (nextPiece[i][j] != 0)
                                        Positioned(
                                          left: j * cellSize + (4 - nextPiece[i].length) * cellSize / 2,
                                          top: i * cellSize + (4 - nextPiece.length) * cellSize / 2,
                                          child: Container(
                                            width: cellSize,
                                            height: cellSize,
                                            decoration: BoxDecoration(
                                              color: pieceColors[nextPiece[i][j]],
                                              border: Border.all(color: Colors.white),
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Spacer(),
                      // Кнопки управления для мобильных устройств
                      Padding(
                        padding: const EdgeInsets.all(0.0), //5
                        child: Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 40),
                              onPressed: rotatePiece,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_left, color: Colors.white, size: 35),
                                  onPressed: moveLeft,
                                ),
                                const SizedBox(width: 5),
                                IconButton(
                                  icon: const Icon(Icons.arrow_right, color: Colors.white, size: 35),
                                  onPressed: moveRight,
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 40),
                              onPressed: moveDown,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Сообщение о конце игры
          if (isGameOver)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Игра окончена!',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Ваш счёт: $currentScore',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        if (currentScore > highScore)
                          const Text(
                            'Новый рекорд!',
                            style: TextStyle(color: Colors.green, fontSize: 16),
                          ),
                        //const SizedBox(height: 5),
                        //ElevatedButton(
                        //  onPressed: startGame,
                        //  child: const Text('Играть снова'),
                        //),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}