-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Tempo de geração: 18-Dez-2023 às 01:49
-- Versão do servidor: 10.4.28-MariaDB
-- versão do PHP: 8.2.4

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Banco de dados: `parte2`
--

DELIMITER $$
--
-- Procedimentos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `AindaNaoEntrevistadosPor` (IN `nome_jornalista` VARCHAR(50))   BEGIN

    SELECT MAX(numero) INTO @edicao_recente FROM edicao;

    SELECT DISTINCT p.nome AS nome_artista
    FROM participante p
    LEFT JOIN entrevista e ON p.codigo = e.Participante_codigo_
    LEFT JOIN jornalista j ON e.Jornalista_codigo = j.codigo
    WHERE (e.Jornalista_codigo IS NULL OR j.nome <> nome_jornalista)
          AND p.Edicao_numero_ = @edicao_recente;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `calcular_total_tecnicos` ()   BEGIN
    UPDATE palco p
    SET p.total_tecnicos = (SELECT COUNT(*) FROM montado m WHERE m.Palco_Edicao_numero_ = p.Edicao_numero AND m.Palco_codigo_ = p.codigo);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Cartaz` (IN `edicao_id` INT)   BEGIN
    SELECT p.nome AS nome_artista, df.data, c.cachet
    FROM participante p
    JOIN contrata c ON p.codigo = c.Participante_codigo_
    JOIN edicao e ON c.Edicao_numero_ = e.numero
    JOIN Dia_Festival df ON c.Dia_Festival_data = df.data
    WHERE e.numero = edicao_id
    ORDER BY df.data ASC, c.cachet DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ClonarEdicao` (IN `EdicaoOrigem` TINYINT(1), IN `DataInicioClone` DATE)   BEGIN
    -- Lógica para clonar a edição
    INSERT INTO Edicao (numero, nome, localidade, local, data_inicio, data_fim, lotacao)
    SELECT
        (SELECT MAX(numero) + 1 FROM Edicao), -- Próximo número de edição
        nome,
        localidade,
        local,
        DataInicioClone AS data_inicio, -- Usando a nova data de início
        NULL AS data_fim, -- Ainda não definido
        lotacao
    FROM Edicao
    WHERE numero = EdicaoOrigem;

    -- Lógica para clonar os dias do festival
    INSERT INTO Dia_festival (Edicao_numero, data)
    SELECT
        (SELECT MAX(numero) FROM Edicao), -- Número da nova edição
        data
    FROM Dia_festival
    WHERE Edicao_numero = EdicaoOrigem;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CriarEdicaoEPalcos` (IN `p_numero` TINYINT, IN `p_nome` VARCHAR(60), IN `p_localidade` VARCHAR(60), IN `p_local` VARCHAR(60), IN `p_data_inicio` DATE, IN `p_data_fim` DATE, IN `p_lotacao` INT, IN `p_palcos` JSON)   BEGIN
    -- Criação da Edição
    INSERT INTO Edicao (numero, nome, localidade, local, data_inicio, data_fim, lotacao)
    VALUES (p_numero, p_nome, p_localidade, p_local, p_data_inicio, p_data_fim, p_lotacao);

    -- Itera sobre a lista de palcos fornecida
    SET @palco_numero := 1;
    SET @palco_nome := JSON_UNQUOTE(JSON_EXTRACT(p_palcos, CONCAT('$[', @palco_numero - 1, '].nome')));

    WHILE @palco_nome IS NOT NULL DO
        -- Criação do Palco
        INSERT INTO palco (Edicao_numero, codigo, nome)
        VALUES (p_numero, @palco_numero, @palco_nome);

        SET @palco_numero := @palco_numero + 1;
        SET @palco_nome := JSON_UNQUOTE(JSON_EXTRACT(p_palcos, CONCAT('$[', @palco_numero - 1, '].nome')));
    END WHILE;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EntrevistadosPor` (IN `edicao_numero` INT, IN `nome_jornalista` VARCHAR(50))   BEGIN

    SELECT DISTINCT p.nome AS nome_artista
    FROM participante p
    JOIN entrevista e ON p.codigo = e.Participante_codigo_
    JOIN jornalista j ON e.Jornalista_codigo = j.codigo
    JOIN edicao ed ON p.Edicao_numero_ = ed.numero
    WHERE ed.numero = edicao_numero AND j.nome = nome_jornalista;
END$$

--
-- Funções
--
CREATE DEFINER=`root`@`localhost` FUNCTION `CalcularMedia` () RETURNS DECIMAL(10,2)  BEGIN
    DECLARE total_lucro DECIMAL(10,2);
    DECLARE total_edicoes INT;
    DECLARE media DECIMAL(10,2);

    -- Calcula o total do lucro e o número total de edições
    SELECT SUM(lucro), COUNT(DISTINCT ano)
    INTO total_lucro, total_edicoes
    FROM lucro_por_edicao;

    -- Calcula a média (evita a divisão por zero)
    IF total_edicoes > 0 THEN
        SET media = total_lucro / total_edicoes;
    ELSE
        SET media = 0;
    END IF;

    RETURN media;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `CalcularNumeroParticipantesUltimaEdicao` () RETURNS INT(11)  BEGIN
    DECLARE ultima_edicao INT;
    DECLARE num_participantes INT;

    -- Obtém o número da última edição
    SELECT MAX(numero) INTO ultima_edicao FROM edicao;

    -- Calcula o número de participantes da última edição
    SELECT COUNT(codigo) INTO num_participantes
    FROM participante
    WHERE EXISTS (
        SELECT 1
        FROM contrata
        WHERE Edicao_numero_ = ultima_edicao AND Participante_codigo_ = codigo
    );

    RETURN num_participantes;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `Qtd_espetadores_no_dia` (`edicao_id` INT, `data_do_dia` DATE) RETURNS INT(11)  BEGIN
    DECLARE quantidade_espetadores INT;

    SELECT COUNT(DISTINCT e.codigo_barras) INTO quantidade_espetadores
    FROM Bilhete b
    JOIN Edicao e ON b.Edicao_numero_ = e.numero
    WHERE e.numero = edicao_id AND b.Dia_Festival_data = data_do_dia;

    RETURN quantidade_espetadores;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura da tabela `acesso`
--

CREATE TABLE `acesso` (
  `Dia_festival_data_` date NOT NULL,
  `Tipo_de_bilhete_Nome_` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `bilhete`
--

CREATE TABLE `bilhete` (
  `num_serie` int(11) NOT NULL,
  `Tipo_de_bilhete_Nome` varchar(30) NOT NULL,
  `Espetador_com_bilhete_Espetador_identificador` int(11) DEFAULT NULL,
  `designacao` varchar(60) DEFAULT NULL,
  `devolvido` tinyint(1) DEFAULT 0,
  `data` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `bilhete`
--

INSERT INTO `bilhete` (`num_serie`, `Tipo_de_bilhete_Nome`, `Espetador_com_bilhete_Espetador_identificador`, `designacao`, `devolvido`, `data`) VALUES
(3, 'A', 1, 'Designacao Bilhete 1', 0, '2023-01-01');

--
-- Acionadores `bilhete`
--
DELIMITER $$
CREATE TRIGGER `verifica_lotacao_diaria` BEFORE INSERT ON `bilhete` FOR EACH ROW BEGIN
    DECLARE qtd_atual INT;

    -- Obtém a quantidade atual de espectadores no dia do festival
    SELECT qtd_espetadores INTO qtd_atual
    FROM Dia_festival
    WHERE data = NEW.data;

    -- Verifica se a lotação já foi atingida
    IF qtd_atual >= (SELECT lotacao FROM Edicao WHERE numero = (SELECT Edicao_numero FROM Dia_festival WHERE data = NEW.data)) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lotação diária do recinto já foi atingida.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura da tabela `contrata`
--

CREATE TABLE `contrata` (
  `Edicao_numero_` tinyint(4) NOT NULL,
  `Participante_codigo_` smallint(6) NOT NULL,
  `cachet` int(11) DEFAULT NULL,
  `Palco_Edicao_numero` tinyint(4) NOT NULL,
  `Palco_codigo` tinyint(4) NOT NULL,
  `Dia_festival_data` date NOT NULL,
  `hora_inicio` time DEFAULT NULL,
  `hora_fim` time DEFAULT NULL,
  `Convidado_Edicao_numero_` tinyint(4) NOT NULL,
  `Convidado_Participante_codigo_` smallint(6) NOT NULL,
  `custo_total` decimal(10,2) GENERATED ALWAYS AS (`cachet`) STORED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `contrata`
--

INSERT INTO `contrata` (`Edicao_numero_`, `Participante_codigo_`, `cachet`, `Palco_Edicao_numero`, `Palco_codigo`, `Dia_festival_data`, `hora_inicio`, `hora_fim`, `Convidado_Edicao_numero_`, `Convidado_Participante_codigo_`) VALUES
(1, 1, 500, 1, 1, '2023-01-01', '18:00:00', '20:00:00', 1, 1);

-- --------------------------------------------------------

--
-- Estrutura da tabela `dia_festival`
--

CREATE TABLE `dia_festival` (
  `Edicao_numero` tinyint(4) NOT NULL,
  `data` date NOT NULL,
  `qtd_espetadores` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `dia_festival`
--

INSERT INTO `dia_festival` (`Edicao_numero`, `data`, `qtd_espetadores`) VALUES
(1, '2023-01-01', 0);

-- --------------------------------------------------------

--
-- Estrutura da tabela `edicao`
--

CREATE TABLE `edicao` (
  `numero` tinyint(4) NOT NULL,
  `nome` varchar(60) DEFAULT NULL,
  `localidade` varchar(60) DEFAULT NULL,
  `local` varchar(60) DEFAULT NULL,
  `data_inicio` date DEFAULT NULL,
  `data_fim` date DEFAULT NULL,
  `lotacao` int(11) DEFAULT NULL,
  `duracao_em_dias` int(11) GENERATED ALWAYS AS (to_days(`data_fim`) - to_days(`data_inicio`)) STORED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `edicao`
--

INSERT INTO `edicao` (`numero`, `nome`, `localidade`, `local`, `data_inicio`, `data_fim`, `lotacao`) VALUES
(1, 'Edição de Teste', 'Localidade Teste', 'Local Teste', '2023-01-01', '2023-01-03', 1000);

-- --------------------------------------------------------

--
-- Estrutura da tabela `elemento_grupo`
--

CREATE TABLE `elemento_grupo` (
  `Individual_Participante_codigo_` smallint(6) NOT NULL,
  `Grupo_Participante_codigo_` smallint(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `entrevista`
--

CREATE TABLE `entrevista` (
  `Participante_codigo_` smallint(6) NOT NULL,
  `Jornalista_num_carteira_profissional_` int(11) NOT NULL,
  `data` date DEFAULT NULL,
  `hora` time DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `espetador_com_bilhete`
--

CREATE TABLE `espetador_com_bilhete` (
  `Espetador_identificador` int(11) NOT NULL,
  `Tipo` enum('Pagante','Convidado') NOT NULL,
  `idade` tinyint(4) NOT NULL,
  `profissao` varchar(20) DEFAULT NULL,
  `nome` varchar(20) NOT NULL,
  `genero` enum('M','F') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `espetador_com_bilhete`
--

INSERT INTO `espetador_com_bilhete` (`Espetador_identificador`, `Tipo`, `idade`, `profissao`, `nome`, `genero`) VALUES
(1, 'Pagante', 0, NULL, 'Nome do Espetador', 'M');

-- --------------------------------------------------------

--
-- Estrutura da tabela `estilo`
--

CREATE TABLE `estilo` (
  `Nome` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `estilos_musicais_por_edicao`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `estilos_musicais_por_edicao` (
);

-- --------------------------------------------------------

--
-- Estrutura da tabela `estilo_de_artista`
--

CREATE TABLE `estilo_de_artista` (
  `Participante_codigo_` smallint(6) NOT NULL,
  `Estilo_Nome_` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `grupo`
--

CREATE TABLE `grupo` (
  `Participante_codigo` smallint(6) NOT NULL,
  `qtd_elementos` tinyint(4) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `individual`
--

CREATE TABLE `individual` (
  `Participante_codigo` smallint(6) NOT NULL,
  `Pais_nome` varchar(60) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `jornalista`
--

CREATE TABLE `jornalista` (
  `Espetador_identificador` int(11) NOT NULL,
  `Media_nome` varchar(30) NOT NULL,
  `num_carteira_profissional` int(11) NOT NULL,
  `nome` varchar(20) NOT NULL,
  `genero` enum('M','F') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `livre_transito`
--

CREATE TABLE `livre_transito` (
  `Edicao_numero_` tinyint(4) NOT NULL,
  `Jornalista_num_carteira_profissional_` int(11) NOT NULL,
  `numero` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `media`
--

CREATE TABLE `media` (
  `nome` varchar(30) NOT NULL,
  `tipo` enum('Rádio','TV','Jornal','Revista') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `montado`
--

CREATE TABLE `montado` (
  `Palco_Edicao_numero_` tinyint(4) NOT NULL,
  `Palco_codigo_` tinyint(4) NOT NULL,
  `Tecnico_numero_` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Acionadores `montado`
--
DELIMITER $$
CREATE TRIGGER `roadie_monta_palco` BEFORE INSERT ON `montado` FOR EACH ROW BEGIN
    DECLARE participante_artista INT;
    
    -- Obtém o código do participante associado ao roadie
    SELECT Participante_codigo INTO participante_artista
    FROM roadie
    WHERE Tecnico_numero = NEW.Tecnico_numero_;

    -- Verifica se o palco pertence ao artista associado ao roadie
    IF participante_artista IS NOT NULL AND participante_artista != NEW.Tecnico_numero_ THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Roadies só podem montar o palco do seu artista.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura da tabela `pais`
--

CREATE TABLE `pais` (
  `nome` varchar(60) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `palco`
--

CREATE TABLE `palco` (
  `Edicao_numero` tinyint(4) NOT NULL,
  `codigo` tinyint(4) NOT NULL,
  `nome` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `palco`
--

INSERT INTO `palco` (`Edicao_numero`, `codigo`, `nome`) VALUES
(1, 1, 'Palco A'),
(1, 2, 'Palco B'),
(1, 3, 'Palco C');

-- --------------------------------------------------------

--
-- Estrutura da tabela `papel`
--

CREATE TABLE `papel` (
  `Nome` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `papel_no_grupo`
--

CREATE TABLE `papel_no_grupo` (
  `Elemento_grupo_Individual_Participante_codigo__` smallint(6) NOT NULL,
  `Elemento_grupo_Grupo_Participante_codigo__` smallint(6) NOT NULL,
  `Papel_Nome_` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `participante`
--

CREATE TABLE `participante` (
  `codigo` smallint(6) NOT NULL,
  `nome` varchar(80) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `participante`
--

INSERT INTO `participante` (`codigo`, `nome`) VALUES
(1, 'Participante 1'),
(2, 'Participante 2'),
(3, 'Participante 3');

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `q1_view`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `q1_view` (
`nome_artista` varchar(80)
,`data` date
,`cachet` int(11)
);

-- --------------------------------------------------------

--
-- Estrutura da tabela `reportagem`
--

CREATE TABLE `reportagem` (
  `Dia_festival_data_` date NOT NULL,
  `Jornalista_num_carteira_profissional_` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `resultados_diarios`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `resultados_diarios` (
);

-- --------------------------------------------------------

--
-- Estrutura da tabela `roadie`
--

CREATE TABLE `roadie` (
  `Tecnico_numero` int(11) NOT NULL,
  `Participante_codigo` smallint(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `roadie`
--

INSERT INTO `roadie` (`Tecnico_numero`, `Participante_codigo`) VALUES
(1, 1);

-- --------------------------------------------------------

--
-- Estrutura da tabela `tecnico`
--

CREATE TABLE `tecnico` (
  `numero` int(11) NOT NULL,
  `nome` varchar(120) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `tecnico`
--

INSERT INTO `tecnico` (`numero`, `nome`) VALUES
(1, 'Francisco');

-- --------------------------------------------------------

--
-- Estrutura da tabela `tema`
--

CREATE TABLE `tema` (
  `Edicao_numero` tinyint(4) NOT NULL,
  `Participante_codigo` smallint(6) NOT NULL,
  `nr_ordem` tinyint(4) NOT NULL,
  `titulo` varchar(60) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `tipo_de_bilhete`
--

CREATE TABLE `tipo_de_bilhete` (
  `Nome` varchar(30) NOT NULL,
  `preco` decimal(6,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `tipo_de_bilhete`
--

INSERT INTO `tipo_de_bilhete` (`Nome`, `preco`) VALUES
('A', 50.00),
('B', 40.00),
('C', 30.00);

-- --------------------------------------------------------

--
-- Estrutura stand-in para vista `todos_os_participantes`
-- (Veja abaixo para a view atual)
--
CREATE TABLE `todos_os_participantes` (
`Nome_Artista` varchar(80)
,`Anos_Ultima_Atuação` int(4)
,`Ultimo_Cachet` int(11)
);

-- --------------------------------------------------------

--
-- Estrutura para vista `estilos_musicais_por_edicao`
--
DROP TABLE IF EXISTS `estilos_musicais_por_edicao`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `estilos_musicais_por_edicao`  AS SELECT `q4_view`.`estilo_de_artista` AS `estilo_de_artista`, `q4_view`.`Estilo` AS `Estilo`, `q4_view`.`Qtd_artistas` AS `Qtd_artistas` FROM `q4_view` ;

-- --------------------------------------------------------

--
-- Estrutura para vista `q1_view`
--
DROP TABLE IF EXISTS `q1_view`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `q1_view`  AS SELECT `p`.`nome` AS `nome_artista`, `df`.`data` AS `data`, `c`.`cachet` AS `cachet` FROM (((`participante` `p` join `contrata` `c` on(`p`.`codigo` = `c`.`Participante_codigo_`)) join `edicao` `e` on(`c`.`Edicao_numero_` = `e`.`numero`)) join `dia_festival` `df` on(`c`.`Dia_festival_data` = `df`.`data`)) ORDER BY `df`.`data` ASC, `c`.`cachet` DESC ;

-- --------------------------------------------------------

--
-- Estrutura para vista `resultados_diarios`
--
DROP TABLE IF EXISTS `resultados_diarios`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `resultados_diarios`  AS SELECT `q2_view`.`dia` AS `dia`, `q2_view`.`quantidade_espetadores` AS `quantidade_espetadores`, `q2_view`.`faturacao` AS `faturacao` FROM `q2_view` ;

-- --------------------------------------------------------

--
-- Estrutura para vista `todos_os_participantes`
--
DROP TABLE IF EXISTS `todos_os_participantes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `todos_os_participantes`  AS SELECT `p`.`nome` AS `Nome_Artista`, ifnull(year(max(`df`.`data`)),0) AS `Anos_Ultima_Atuação`, max(`c`.`cachet`) AS `Ultimo_Cachet` FROM ((`participante` `p` left join `contrata` `c` on(`p`.`codigo` = `c`.`Participante_codigo_`)) left join `dia_festival` `df` on(`c`.`Dia_festival_data` = `df`.`data`)) GROUP BY `p`.`nome` ;

--
-- Índices para tabelas despejadas
--

--
-- Índices para tabela `acesso`
--
ALTER TABLE `acesso`
  ADD PRIMARY KEY (`Dia_festival_data_`,`Tipo_de_bilhete_Nome_`),
  ADD KEY `FK_Tipo_de_bilhete_acesso_Dia_festival_` (`Tipo_de_bilhete_Nome_`);

--
-- Índices para tabela `bilhete`
--
ALTER TABLE `bilhete`
  ADD PRIMARY KEY (`num_serie`),
  ADD KEY `FK_Bilhete_noname_Tipo_de_bilhete` (`Tipo_de_bilhete_Nome`),
  ADD KEY `FK_Bilhete_tem_Espetador_com_bilhete` (`Espetador_com_bilhete_Espetador_identificador`);

--
-- Índices para tabela `contrata`
--
ALTER TABLE `contrata`
  ADD PRIMARY KEY (`Edicao_numero_`,`Participante_codigo_`),
  ADD KEY `FK_Participante_Contrata_Edicao_` (`Participante_codigo_`),
  ADD KEY `FK_Contrata_apresenta_Palco` (`Palco_Edicao_numero`,`Palco_codigo`),
  ADD KEY `FK_Contrata_Atuacao_Dia_festival` (`Dia_festival_data`),
  ADD KEY `FK_Participante_Convida_Participante_` (`Convidado_Edicao_numero_`,`Convidado_Participante_codigo_`);

--
-- Índices para tabela `dia_festival`
--
ALTER TABLE `dia_festival`
  ADD PRIMARY KEY (`data`),
  ADD KEY `FK_Dia_festival_noname_Edicao` (`Edicao_numero`);

--
-- Índices para tabela `edicao`
--
ALTER TABLE `edicao`
  ADD PRIMARY KEY (`numero`);

--
-- Índices para tabela `elemento_grupo`
--
ALTER TABLE `elemento_grupo`
  ADD PRIMARY KEY (`Individual_Participante_codigo_`,`Grupo_Participante_codigo_`),
  ADD KEY `FK_Grupo_Elemento_grupo_Individual_` (`Grupo_Participante_codigo_`);

--
-- Índices para tabela `entrevista`
--
ALTER TABLE `entrevista`
  ADD PRIMARY KEY (`Participante_codigo_`,`Jornalista_num_carteira_profissional_`),
  ADD KEY `FK_Jornalista_Entrevista_Participante_` (`Jornalista_num_carteira_profissional_`);

--
-- Índices para tabela `espetador_com_bilhete`
--
ALTER TABLE `espetador_com_bilhete`
  ADD PRIMARY KEY (`Espetador_identificador`);

--
-- Índices para tabela `estilo`
--
ALTER TABLE `estilo`
  ADD PRIMARY KEY (`Nome`);

--
-- Índices para tabela `estilo_de_artista`
--
ALTER TABLE `estilo_de_artista`
  ADD PRIMARY KEY (`Participante_codigo_`,`Estilo_Nome_`),
  ADD KEY `FK_Estilo_estilo_de_artista_Participante_` (`Estilo_Nome_`);

--
-- Índices para tabela `grupo`
--
ALTER TABLE `grupo`
  ADD PRIMARY KEY (`Participante_codigo`);

--
-- Índices para tabela `individual`
--
ALTER TABLE `individual`
  ADD PRIMARY KEY (`Participante_codigo`),
  ADD KEY `FK_Individual_origem_Pais` (`Pais_nome`);

--
-- Índices para tabela `jornalista`
--
ALTER TABLE `jornalista`
  ADD PRIMARY KEY (`num_carteira_profissional`),
  ADD KEY `FK_Jornalista_Espetador` (`Espetador_identificador`),
  ADD KEY `FK_Jornalista_representa_Media` (`Media_nome`);

--
-- Índices para tabela `livre_transito`
--
ALTER TABLE `livre_transito`
  ADD PRIMARY KEY (`Edicao_numero_`,`Jornalista_num_carteira_profissional_`),
  ADD KEY `FK_Jornalista_Livre_transito_Edicao_` (`Jornalista_num_carteira_profissional_`);

--
-- Índices para tabela `media`
--
ALTER TABLE `media`
  ADD PRIMARY KEY (`nome`);

--
-- Índices para tabela `montado`
--
ALTER TABLE `montado`
  ADD PRIMARY KEY (`Palco_Edicao_numero_`,`Palco_codigo_`,`Tecnico_numero_`),
  ADD KEY `FK_Tecnico_montado_Palco_` (`Tecnico_numero_`);

--
-- Índices para tabela `pais`
--
ALTER TABLE `pais`
  ADD PRIMARY KEY (`nome`);

--
-- Índices para tabela `palco`
--
ALTER TABLE `palco`
  ADD PRIMARY KEY (`Edicao_numero`,`codigo`);

--
-- Índices para tabela `papel`
--
ALTER TABLE `papel`
  ADD PRIMARY KEY (`Nome`);

--
-- Índices para tabela `papel_no_grupo`
--
ALTER TABLE `papel_no_grupo`
  ADD PRIMARY KEY (`Elemento_grupo_Individual_Participante_codigo__`,`Elemento_grupo_Grupo_Participante_codigo__`,`Papel_Nome_`),
  ADD KEY `FK_Papel_papel_no_grupo_Elemento_grupo_` (`Papel_Nome_`);

--
-- Índices para tabela `participante`
--
ALTER TABLE `participante`
  ADD PRIMARY KEY (`codigo`);

--
-- Índices para tabela `reportagem`
--
ALTER TABLE `reportagem`
  ADD PRIMARY KEY (`Dia_festival_data_`,`Jornalista_num_carteira_profissional_`),
  ADD KEY `FK_Jornalista_Reportagem_Dia_festival_` (`Jornalista_num_carteira_profissional_`);

--
-- Índices para tabela `roadie`
--
ALTER TABLE `roadie`
  ADD PRIMARY KEY (`Tecnico_numero`),
  ADD KEY `FK_Roadie_ligado_Participante` (`Participante_codigo`);

--
-- Índices para tabela `tecnico`
--
ALTER TABLE `tecnico`
  ADD PRIMARY KEY (`numero`);

--
-- Índices para tabela `tema`
--
ALTER TABLE `tema`
  ADD PRIMARY KEY (`Edicao_numero`,`Participante_codigo`,`nr_ordem`);

--
-- Índices para tabela `tipo_de_bilhete`
--
ALTER TABLE `tipo_de_bilhete`
  ADD PRIMARY KEY (`Nome`);

--
-- AUTO_INCREMENT de tabelas despejadas
--

--
-- AUTO_INCREMENT de tabela `bilhete`
--
ALTER TABLE `bilhete`
  MODIFY `num_serie` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- Restrições para despejos de tabelas
--

--
-- Limitadores para a tabela `acesso`
--
ALTER TABLE `acesso`
  ADD CONSTRAINT `FK_Dia_festival_acesso_Tipo_de_bilhete_` FOREIGN KEY (`Dia_festival_data_`) REFERENCES `dia_festival` (`data`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Tipo_de_bilhete_acesso_Dia_festival_` FOREIGN KEY (`Tipo_de_bilhete_Nome_`) REFERENCES `tipo_de_bilhete` (`Nome`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `bilhete`
--
ALTER TABLE `bilhete`
  ADD CONSTRAINT `FK_Bilhete_noname_Tipo_de_bilhete` FOREIGN KEY (`Tipo_de_bilhete_Nome`) REFERENCES `tipo_de_bilhete` (`Nome`) ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Bilhete_tem_Espetador_com_bilhete` FOREIGN KEY (`Espetador_com_bilhete_Espetador_identificador`) REFERENCES `espetador_com_bilhete` (`Espetador_identificador`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Limitadores para a tabela `contrata`
--
ALTER TABLE `contrata`
  ADD CONSTRAINT `FK_Contrata_Atuacao_Dia_festival` FOREIGN KEY (`Dia_festival_data`) REFERENCES `dia_festival` (`data`) ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Contrata_apresenta_Palco` FOREIGN KEY (`Palco_Edicao_numero`,`Palco_codigo`) REFERENCES `palco` (`Edicao_numero`, `codigo`) ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Edicao_Contrata_Participante_` FOREIGN KEY (`Edicao_numero_`) REFERENCES `edicao` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Participante_Contrata_Edicao_` FOREIGN KEY (`Participante_codigo_`) REFERENCES `participante` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Participante_Convida_Participante_` FOREIGN KEY (`Convidado_Edicao_numero_`,`Convidado_Participante_codigo_`) REFERENCES `contrata` (`Edicao_numero_`, `Participante_codigo_`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `dia_festival`
--
ALTER TABLE `dia_festival`
  ADD CONSTRAINT `FK_Dia_festival_noname_Edicao` FOREIGN KEY (`Edicao_numero`) REFERENCES `edicao` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `elemento_grupo`
--
ALTER TABLE `elemento_grupo`
  ADD CONSTRAINT `FK_Grupo_Elemento_grupo_Individual_` FOREIGN KEY (`Grupo_Participante_codigo_`) REFERENCES `grupo` (`Participante_codigo`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Individual_Elemento_grupo_Grupo_` FOREIGN KEY (`Individual_Participante_codigo_`) REFERENCES `individual` (`Participante_codigo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `entrevista`
--
ALTER TABLE `entrevista`
  ADD CONSTRAINT `FK_Jornalista_Entrevista_Participante_` FOREIGN KEY (`Jornalista_num_carteira_profissional_`) REFERENCES `jornalista` (`num_carteira_profissional`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Participante_Entrevista_Jornalista_` FOREIGN KEY (`Participante_codigo_`) REFERENCES `participante` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `estilo_de_artista`
--
ALTER TABLE `estilo_de_artista`
  ADD CONSTRAINT `FK_Estilo_estilo_de_artista_Participante_` FOREIGN KEY (`Estilo_Nome_`) REFERENCES `estilo` (`Nome`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Participante_estilo_de_artista_Estilo_` FOREIGN KEY (`Participante_codigo_`) REFERENCES `participante` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `grupo`
--
ALTER TABLE `grupo`
  ADD CONSTRAINT `FK_Grupo_Participante` FOREIGN KEY (`Participante_codigo`) REFERENCES `participante` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `individual`
--
ALTER TABLE `individual`
  ADD CONSTRAINT `FK_Individual_Participante` FOREIGN KEY (`Participante_codigo`) REFERENCES `participante` (`codigo`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Individual_origem_Pais` FOREIGN KEY (`Pais_nome`) REFERENCES `pais` (`nome`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Limitadores para a tabela `jornalista`
--
ALTER TABLE `jornalista`
  ADD CONSTRAINT `FK_Jornalista_representa_Media` FOREIGN KEY (`Media_nome`) REFERENCES `media` (`nome`) ON UPDATE CASCADE;

--
-- Limitadores para a tabela `livre_transito`
--
ALTER TABLE `livre_transito`
  ADD CONSTRAINT `FK_Edicao_Livre_transito_Jornalista_` FOREIGN KEY (`Edicao_numero_`) REFERENCES `edicao` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Jornalista_Livre_transito_Edicao_` FOREIGN KEY (`Jornalista_num_carteira_profissional_`) REFERENCES `jornalista` (`num_carteira_profissional`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `montado`
--
ALTER TABLE `montado`
  ADD CONSTRAINT `FK_Palco_montado_Tecnico_` FOREIGN KEY (`Palco_Edicao_numero_`,`Palco_codigo_`) REFERENCES `palco` (`Edicao_numero`, `codigo`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Tecnico_montado_Palco_` FOREIGN KEY (`Tecnico_numero_`) REFERENCES `tecnico` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `palco`
--
ALTER TABLE `palco`
  ADD CONSTRAINT `FK_Palco_tem_Edicao` FOREIGN KEY (`Edicao_numero`) REFERENCES `edicao` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `papel_no_grupo`
--
ALTER TABLE `papel_no_grupo`
  ADD CONSTRAINT `FK_Elemento_grupo_papel_no_grupo_Papel_` FOREIGN KEY (`Elemento_grupo_Individual_Participante_codigo__`,`Elemento_grupo_Grupo_Participante_codigo__`) REFERENCES `elemento_grupo` (`Individual_Participante_codigo_`, `Grupo_Participante_codigo_`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Papel_papel_no_grupo_Elemento_grupo_` FOREIGN KEY (`Papel_Nome_`) REFERENCES `papel` (`Nome`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `reportagem`
--
ALTER TABLE `reportagem`
  ADD CONSTRAINT `FK_Dia_festival_Reportagem_Jornalista_` FOREIGN KEY (`Dia_festival_data_`) REFERENCES `dia_festival` (`data`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Jornalista_Reportagem_Dia_festival_` FOREIGN KEY (`Jornalista_num_carteira_profissional_`) REFERENCES `jornalista` (`num_carteira_profissional`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `roadie`
--
ALTER TABLE `roadie`
  ADD CONSTRAINT `FK_Roadie_Tecnico` FOREIGN KEY (`Tecnico_numero`) REFERENCES `tecnico` (`numero`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_Roadie_ligado_Participante` FOREIGN KEY (`Participante_codigo`) REFERENCES `participante` (`codigo`) ON UPDATE CASCADE;

--
-- Limitadores para a tabela `tema`
--
ALTER TABLE `tema`
  ADD CONSTRAINT `FK_Tema_enterpretado_Contrata` FOREIGN KEY (`Edicao_numero`,`Participante_codigo`) REFERENCES `contrata` (`Edicao_numero_`, `Participante_codigo_`) ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
