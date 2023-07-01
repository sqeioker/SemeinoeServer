
Функция Синхронизация(Данные) Экспорт
	
	ДанныеСообщения = Данные.Получить();
	Если ДанныеСообщения = "ЭтоПервоеПодключение" Тогда
	   ОтветКлиенту = ПерваяВыгрузка(ДанныеСообщения);
	Иначе	
	   ОтветКлиенту = ЗарегистрироватьВыгрузку(ДанныеСообщения);
	КонецЕсли;
	
	Возврат Новый ХранилищеЗначения(ОтветКлиенту, Новый СжатиеДанных(9));
	
КонецФункции 

Функция ЗарегистрироватьВыгрузку(СтрокаСообщения)  Экспорт
	
	//Обработка полученого сообщения
	ЧтениеXML = Новый ЧтениеXML;	
	ЧтениеXML.УстановитьСтроку(СтрокаСообщения);
	ЧтениеСообщения = Планыобмена.СоздатьЧтениеСообщения();
	ЧтениеСообщения.НачатьЧтение(ЧтениеXML); 
	Отправитель = ЧтениеСообщения.Отправитель;
	Пока ВозможностьЧтенияXML(ЧтениеXML) Цикл
		Данные = ПрочитатьXML(ЧтениеСообщения.ЧтениеXML);
		Если Не Данные = Неопределено Тогда
			Данные.ОбменДанными.Загрузка = Истина;
			Если ТипЗнч(Данные) = Тип("ДокументОбъект.РеализацияТоваровУслуг") Тогда
				Если Данные.Проведен Тогда
					//если получен проведенный документ, то его проводим в фоне
					Данные.Записать();
					П = Новый Массив;
					П.Добавить(Данные.Ссылка);
					ФоновыеЗадания.Выполнить("Получениеданных.ОтложеноеПроведениеДокумента",П); 
				Иначе
					Данные.Записать();	
				КонецЕсли;
			Иначе
				Данные.Записать();	
			КонецЕсли;	
		КонецЕсли; 
	КонецЦикла;
	//удаляются принятые сообщения
	Планыобмена.УдалитьРегистрациюИзменений(Отправитель,Отправитель.НомерПринятого);
	ЧтениеСообщения.ЗакончитьЧтение();
	
	ЗаписатьXML = Новый ЗаписьXML;
	ЗаписатьXML.УстановитьСтроку();
	ЗаписьСообщения = Планыобмена.СоздатьЗаписьСообщения();
	Узел = Отправитель;
	ЗаписьСообщения.НачатьЗапись(ЗаписатьXML,Узел);
	//на этом этапе получаем измеенения, и присваем номер сообщения
	Выборка = ПланыОбмена.ВыбратьИзменения(Узел,ЗаписьСообщения.НомерСообщения);
	Пока Выборка.Следующий() Цикл
		Объект = Выборка.Получить();
		ЗаписатьXML(ЗаписатьXML,Объект); 
	КонецЦикла;
	ЗаписьСообщения.ЗакончитьЗапись();
	ПланОбменаОбъект = Узел.ПолучитьОбъект();
	ПланОбменаОбъект.ДатаОбмена = ТекущаяДата();
	ПланОбменаОбъект.Записать();
	
	Возврат ЗаписатьXML.Закрыть();
	
КонецФункции 

Процедура ОтложеноеПроведениеДокумента(Ссылка) Экспорт
	
	Данные = Ссылка.ПолучитьОбъект();
	Данные.ДополнительныеСвойства.Вставить("Загрузка",Истина);
	Данные.Записать(РежимЗаписиДокумента.Проведение);
	
КонецПроцедуры

Процедура РегистрацияПриЗаписи(Источник, Отказ) Экспорт
	
	Если Не Источник.Обменданными.Загрузка и Не Источник.ДополнительныеСвойства.Свойство("Загрузка") Тогда
		Запрос = Новый Запрос;
		Запрос.Текст = 
		"ВЫБРАТЬ
		|	Мобильный.Ссылка КАК Ссылка,
		|	Мобильный.Код КАК Код
		|ИЗ
		|	ПланОбмена.Мобильный КАК Мобильный";
		
		РезультатЗапроса = Запрос.Выполнить();
		
		ВыборкаДетальныеЗаписи = РезультатЗапроса.Выбрать();
		
		Пока ВыборкаДетальныеЗаписи.Следующий() Цикл 
			Если ВыборкаДетальныеЗаписи.Код = "ЦБ" Тогда
				Продолжить;
			КонецЕсли;
			Планыобмена.ЗарегистрироватьИзменения(ВыборкаДетальныеЗаписи.Ссылка,Источник.Ссылка);			
		КонецЦикла;
	КонецЕсли; 
	
КонецПроцедуры

Функция ПерваяВыгрузка(ДанныеСообщения) Экспорт
	
	//при первом вызове создаем новый узел, генерим  новый код
	Запрос = Новый Запрос;
	Запрос.Текст = 
	"ВЫБРАТЬ
	|	Мобильный.Код КАК Код,
	|	Мобильный.Ссылка КАК Ссылка
	|ИЗ
	|	ПланОбмена.Мобильный КАК Мобильный
	|ГДЕ
	|	НЕ Мобильный.ЭтотУзел";
	
	РезультатЗапроса = Запрос.Выполнить();
	
	ВыборкаДетальныеЗаписи = РезультатЗапроса.Выбрать();
	Код = 1;
	Пока ВыборкаДетальныеЗаписи.Следующий() Цикл
		Попытка			
			КодМакс = Число(ВыборкаДетальныеЗаписи.Код);	
			Если КодМакс >= Код Тогда		  
				Код = КодМакс + 1; 		  
			КонецЕсли;
		Исключение		
		КонецПопытки;
	КонецЦикла; 
	
	НУзел = ПланыОбмена.Мобильный.СоздатьУзел();
    НУзел.Код = Строка(Код);
	НУзел.Наименование = Строка(Код);
	НУзел.Записать();
	СсылкаНаУзел = НУзел.Ссылка; 
	П = Новый Массив;
	П.Добавить(СсылкаНаУзел);
	ФоновыеЗадания.Выполнить("ПолучениеДанных.РегистрацияИзмененийНовыйУзел",П);
	
	Возврат  Строка(Код);
	
КонецФункции

Процедура РегистрацияИзмененийНовыйУзел(СсылкаНаУзел) Экспорт
	
	Запрос = Новый Запрос;
	Запрос.Текст = 
	"ВЫБРАТЬ
	|	РеализацияТоваровУслуг.Ссылка КАК Ссылка
	|ИЗ
	|	Документ.РеализацияТоваровУслуг КАК РеализацияТоваровУслуг
	|ГДЕ
	|	РеализацияТоваровУслуг.Дата > &Дата
	|
	|ОБЪЕДИНИТЬ ВСЕ
	|
	|ВЫБРАТЬ
	|	Пользователи.Ссылка
	|ИЗ
	|	Справочник.Пользователи КАК Пользователи
	|
	|ОБЪЕДИНИТЬ ВСЕ
	|
	|ВЫБРАТЬ
	|	Номенклатура.Ссылка
	|ИЗ
	|	Справочник.Номенклатура КАК Номенклатура
	|
	|ОБЪЕДИНИТЬ ВСЕ
	|
	|ВЫБРАТЬ
	|	ТипыНоменклатуры.Ссылка
	|ИЗ
	|	Справочник.ТипыНоменклатуры КАК ТипыНоменклатуры
	|
	|ОБЪЕДИНИТЬ ВСЕ
	|
	|ВЫБРАТЬ
	|	Контрагенты.Ссылка
	|ИЗ
	|	Справочник.Контрагенты КАК Контрагенты
	|
	|ОБЪЕДИНИТЬ ВСЕ
	|
	|ВЫБРАТЬ
	|	СемейныйЧат.Ссылка
	|ИЗ
	|	Справочник.СемейныйЧат КАК СемейныйЧат
	|
	|ОБЪЕДИНИТЬ ВСЕ
	|
	|ВЫБРАТЬ
	|	Планирование.Ссылка
	|ИЗ
	|	Справочник.Планирование КАК Планирование";
	
	Запрос.УстановитьПараметр("Дата", ТекущаяДата() - 86400 * 60);
	РезультатЗапроса = Запрос.Выполнить();
	
	ВыборкаДетальныеЗаписи = РезультатЗапроса.Выбрать();
	МассивСсылок = Новый Массив();
	Пока ВыборкаДетальныеЗаписи.Следующий() Цикл
		МассивСсылок.Добавить(ВыборкаДетальныеЗаписи.Ссылка);	
	КонецЦикла;
	Планыобмена.ЗарегистрироватьИзменения(СсылкаНаУзел,МассивСсылок);
	
КонецПроцедуры
