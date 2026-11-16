# Changelog

## 1.4.5

- Recognizes additional client formats for the Shadow Word: Death damage range and reports when the range cannot be read.

### По-русски

- Добавлен разбор диапазона урона «Слова Тьмы: Смерть» для других языков клиента. В настройках видна причина, если прочитать диапазон не удалось.

## 1.4.4

- Keeps the last confirmed cooldown state when data is temporarily unavailable. Reads the global cooldown flag during the cooldown event to prevent nameplate icons from flashing between updates.

### По-русски

- Временный пропуск данных о перезарядке сохраняет последнее подтвержденное состояние значка. Глобальная перезарядка проверяется в момент события обновления перезарядки.

## 1.4.3

- Clarified the wording for the threshold marker and minimum threshold filter. Added a tooltip beside each setting.

### По-русски

- Уточнены названия отметки порога добивания и фильтра минимального порога. У каждой настройки есть подсказка.

## 1.4.2

- Shows a cooldown bar, remaining seconds, and a completion message below the preview nameplate. The result describes how the selected cooldown mode affects the icon.

### По-русски

- Под неймплейтом манекена видны полоса перезарядки, оставшиеся секунды и сообщение о завершении теста. Подпись объясняет, что выбранный режим делает со значком.

## 1.4.1

- The cooldown preview moves the dummy into execute range when needed and counts down on the test button. The test is available for each supported ability.

### По-русски

- Тест перезарядки при необходимости опускает здоровье манекена до зоны добивания и показывает обратный отсчет на кнопке. Тест доступен для всех поддерживаемых способностей.

## 1.4.0

- Automatically detects the highest learned rank of Shadow Word: Death, Execute, Hammer of Wrath, or Soul Fire with Decimation.
- Shows the ability's HP estimate or health percentage and uses its game icon by default. The icon dropdown includes six transparent alternatives.

### По-русски

- Автоматически определяется высший изученный ранг «Слова Тьмы: Смерть», «Казни», «Молота гнева» или «Огня души» с талантом Decimation.
- Индикатор показывает расчетный порог в HP или порог в процентах. В выпадающем списке доступны родная иконка способности и шесть прозрачных значков.

## 1.3.13

- Added a themed hint that explains the damage reduction buffer.

### По-русски

- Добавлена подсказка темы о том, как действует запас на снижение урона.

## 1.3.12

First public release baseline for WoW Forever 1.60.1.

- Shadow Word: Death threshold from the highest learned rank, with a configurable damage buffer and display filters.
- Independent fill, threshold marker, and spell icon for Blizzard and EllesmereUI enemy nameplates.
- Settings preview with target health, combat scenarios, and cooldown. Controls for color, size, pulse, and cooldown behavior.
- Shared Sintezza Theme and support for English and Russian spell tooltips.

### По-русски

- Порог «Слова Тьмы: Смерть» из высшего изученного ранга с настройкой запаса урона и условий показа.
- Отдельные заливка, риска и значок для неймплейтов Blizzard и EllesmereUI.
- Предпросмотр здоровья, боевого сценария и перезарядки. Настройки цвета, размера и пульсации.
- Общая тема Sintezza и поддержка английских и русских подсказок заклинания.
