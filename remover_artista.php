<?php
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "parte_2";

$conn = mysqli_connect($servername, $username, $password, $dbname);

if (!$conn) {
    die("A conexão falhou: " . mysqli_connect_error());
}

if (isset($_POST['codigo'])) {
    $codigo = $_POST['codigo'];
    
    $sql1 = "SELECT * FROM participante WHERE codigo = $codigo";
    $sql = "DELETE FROM participante WHERE codigo = $codigo";
    $sql3 = "SELECT * FROM participante";

    if (mysqli_num_rows(mysqli_query($conn, $sql1)) > 0 && mysqli_query($conn, $sql)) {
        echo "Artista cancelado <br>";

        $result = mysqli_query($conn, $sql3);
        while ($row = mysqli_fetch_assoc($result)) {
            echo "NOME: " . $row['nome'] . " - ID: " . $row['codigo'] . "<br>";
        }
    } else {
        echo "0 resultados";
    }

    mysqli_close($conn);
    exit;
}
?>
