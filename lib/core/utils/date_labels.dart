const _months = <String>[
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String compactDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String shortDate(DateTime date) => '${date.day} ${_months[date.month - 1]}';
